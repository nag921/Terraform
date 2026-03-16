##############################################################################
# IAM Role for Lambda
#
# Every Lambda function must have an IAM execution role. This role defines
# WHAT the function is allowed to do (e.g. write logs, access S3, etc.).
#
# Two parts are required:
#   1. Trust policy (assume_role_policy) — tells AWS which service is allowed
#      to "assume" (use) this role. For Lambda it must be "lambda.amazonaws.com".
#   2. Permission policies — attached separately (see aws_iam_role_policy_attachment
#      below), these control what AWS APIs the function can call at runtime.
##############################################################################

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  # Trust policy: allows the Lambda service to assume this role.
  # jsonencode() converts a Terraform map/object into a valid JSON string,
  # which is what the IAM API expects.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # sts:AssumeRole is the action that lets a service "become" this role
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # Only the Lambda service can assume this role
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

##############################################################################
# IAM Policy Attachment
#
# Attaches an AWS-managed policy to the Lambda execution role created above.
#
# AWSLambdaBasicExecutionRole is the minimum policy a Lambda needs — it grants
# permission to write logs to CloudWatch Logs so you can debug your function.
#
# If your function needs to access other services (S3, DynamoDB, SQS, etc.)
# you would attach additional policies here or create a custom inline policy.
##############################################################################

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##############################################################################
# Lambda Function
#
# The actual serverless function. Key arguments explained:
#
#   function_name — unique name for the function within your AWS account/region.
#
#   role          — ARN of the IAM execution role above. Lambda assumes this
#                   role when the function runs, gaining its permissions.
#
#   handler       — entry point in your code, in the format "file.function".
#                   "lambda_function.handler" means: call the function named
#                   `handler` inside the file `lambda_function.py`.
#
#   runtime       — the language/version environment to run your code in.
#                   "python3.12" uses the AWS-managed Python 3.12 runtime.
#
#   filename      — path to a local .zip file containing your function code.
#                   Terraform uploads this zip to Lambda on every apply when
#                   the file contents change (tracked via source_code_hash).
#                   Alternatively, use s3_bucket/s3_key for large packages.
#
#   source_code_hash — a base64-encoded SHA256 hash of the zip file contents.
#                   Terraform compares this hash on every `plan`/`apply`. If the
#                   hash changes (i.e. your code changed), Terraform knows to
#                   re-upload and redeploy the function. Without this, Terraform
#                   only redeploys if the filename itself changes — so code edits
#                   inside the same zip would be silently ignored.
##############################################################################

resource "aws_lambda_function" "my_lambda" {
  function_name    = "my_lambda_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  filename         = "lambda_function.zip"

  # filebase64sha256() reads the zip at plan time and produces a hash.
  # Terraform stores this hash in state. On the next apply, if the hash
  # differs from state, it triggers a function update — even if the
  # filename "lambda_function.zip" hasn't changed.
  source_code_hash = filebase64sha256("lambda_function.zip")
}