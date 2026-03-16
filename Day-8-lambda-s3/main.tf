##############################################################################
# Data Source: Current AWS Account Identity
#
# data sources are READ-ONLY lookups — they fetch existing information from
# AWS without creating anything.
#
# aws_caller_identity returns details about the AWS account and IAM identity
# that Terraform is running as. We use the account_id here to construct a
# globally unique S3 bucket name, since S3 bucket names must be unique
# across ALL AWS accounts worldwide.
##############################################################################

data "aws_caller_identity" "current" {}

##############################################################################
# Locals
#
# locals{} defines reusable values computed once and referenced anywhere in
# the config with local.<name>. Think of them as constants or derived values.
#
# zip_file_path references the package built by build.ps1 / build.sh.
# Centralising it here means a filename change only needs one edit.
##############################################################################

locals {
  bucket_name   = "lambda-packages-${data.aws_caller_identity.current.account_id}"
  zip_file_path = "${path.module}/lambda_function.zip"
}

##############################################################################
# S3 Bucket
#
# This bucket stores the Lambda deployment package (.zip).
# Uploading to S3 first is the recommended approach for packages over ~10 MB,
# and is required for packages over 50 MB (the direct upload limit).
#
# Additional benefits over direct filename= upload:
#   - Versioning: keep history of every deployment package
#   - Auditability: see exactly what code was deployed and when
#   - Reuse: multiple Lambda functions can reference the same package
#   - CI/CD friendly: pipelines push to S3, Terraform references it
##############################################################################

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = local.bucket_name

  tags = {
    Name = "lambda-packages"
  }
}

##############################################################################
# S3 Bucket Versioning
#
# Enabling versioning keeps every version of every object ever uploaded.
# This is important for Lambda deployments because:
#   - You can roll back to a previous version of your function code
#   - aws_lambda_function can reference a specific s3_object_version
#     to pin a deployment to an exact package version
##############################################################################

resource "aws_s3_bucket_versioning" "lambda_bucket_versioning" {
  bucket = aws_s3_bucket.lambda_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

##############################################################################
# S3 Bucket Public Access Block
#
# Best practice: always block all public access on buckets that store code
# or sensitive data. Lambda reads from S3 using its IAM role — public access
# is never needed.
##############################################################################

resource "aws_s3_bucket_public_access_block" "lambda_bucket_public_access" {
  bucket = aws_s3_bucket.lambda_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##############################################################################
# S3 Object — Lambda Deployment Package
#
# This uploads the local zip file to the S3 bucket.
#
#   bucket      — the destination bucket.
#   key         — the object name (path) inside the bucket.
#   source      — path to the local file to upload.
#   source_code_hash  — same as with filename= deployment: Terraform compares
#                   this hash against state to detect code changes and re-upload
#                   only when the zip content has actually changed.
#
# After Terraform runs this resource, the zip lives at:
#   s3://lambda-packages-<account_id>/lambda_function.zip
##############################################################################

resource "aws_s3_object" "lambda_package" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_function.zip"
  source = local.zip_file_path

  # Triggers re-upload whenever the zip contents change
  source_hash = filebase64sha256(local.zip_file_path)
}

##############################################################################
# IAM Role for Lambda
#
# Same as direct-upload deployments — Lambda still needs an execution role
# with a trust policy allowing lambda.amazonaws.com to assume it.
##############################################################################

resource "aws_iam_role" "lambda_role" {
  name = "lambda_s3_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Minimum permissions: write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################################################################
# Lambda Function — S3 Deployment
#
# KEY DIFFERENCE from Day-8-Lambda-practice:
#
#   Direct upload (Day-8):         S3 deployment (this file):
#   ─────────────────────          ──────────────────────────
#   filename = "file.zip"          s3_bucket = <bucket name>
#   source_code_hash = ...         s3_key     = <object key>
#                                  s3_object_version = <version> (optional)
#
#   s3_bucket         — name of the S3 bucket holding the package.
#   s3_key            — path/name of the zip object inside the bucket.
#   s3_object_version — (optional) pin to a specific version ID when bucket
#                       versioning is enabled. Omitting it uses the latest.
#                       Including it makes deployments fully reproducible.
#
# depends_on ensures the S3 object is uploaded before Lambda tries to
# reference it. Terraform usually infers this from attribute references,
# but it's explicit here for clarity.
##############################################################################

resource "aws_lambda_function" "my_lambda_s3" {
  function_name = "my_lambda_s3_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"

  # --- S3-based deployment (replaces filename=) ---
  s3_bucket         = aws_s3_object.lambda_package.bucket
  s3_key            = aws_s3_object.lambda_package.key
  s3_object_version = aws_s3_object.lambda_package.version_id

  # source_code_hash tells Lambda to redeploy when the zip contents change.
  source_code_hash = filebase64sha256(local.zip_file_path)

  depends_on = [aws_s3_object.lambda_package]

  tags = {
    Name = "my-lambda-s3"
  }
}
