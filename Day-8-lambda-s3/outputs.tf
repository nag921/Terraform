##############################################################################
# Outputs
#
# output{} values are printed after `terraform apply` and can be queried
# with `terraform output`. Useful for referencing deployed resource details
# without having to look them up in the AWS console.
##############################################################################

output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.my_lambda_s3.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.my_lambda_s3.arn
}

output "s3_bucket_name" {
  description = "S3 bucket storing the Lambda deployment package"
  value       = aws_s3_bucket.lambda_bucket.bucket
}
