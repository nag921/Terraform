
#IAM role for Lambda execution
resource "aws_iam_role" "lambda_exec" {
    name = "lambda_exec_role"

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

# Attach AWSLambdaBasicExecutionRole policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# create Lambda function
resource "aws_lambda_function" "example1" {
    function_name = "example-scheduled-lambda"
    handler       = "lambda_function.handler"
    runtime       = "python3.12"
    role          = aws_iam_role.lambda_exec.arn
    filename      = "lambda_function.zip"
}

#create EventBridge rule to trigger Lambda every 5 minutes
resource "aws_cloudwatch_event_rule" "every_5_minutes" {
    name                = "every-5-minutes"
    schedule_expression = "rate(5 minutes)"
}

# create EventBridge target to link the rule to the Lambda function
resource "aws_cloudwatch_event_target" "lambda_target" {
    rule      = aws_cloudwatch_event_rule.every_5_minutes.name
    target_id = "lambda_target"
    arn       = aws_lambda_function.example1.arn
}

# grant EventBridge permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
    statement_id  = "AllowExecutionFromEventBridge"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.example1.function_name
    principal     = "events.amazonaws.com"
    source_arn    = aws_cloudwatch_event_rule.every_5_minutes.arn
}   