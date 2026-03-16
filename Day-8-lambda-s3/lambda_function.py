import json
import os


def handler(event, context):
    """
    Sample Lambda function demonstrating S3-based deployment.

    'event'   — dict containing the input data passed to the function
                (e.g. from API Gateway, S3 trigger, EventBridge, etc.)
    'context' — runtime info: function name, memory limit, request ID, etc.
    """

    print(f"Function name : {context.function_name}")
    print(f"Request ID    : {context.aws_request_id}")
    print(f"Received event: {json.dumps(event)}")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": "Hello from Lambda deployed via S3!",
            "input_event": event,
            "function_name": context.function_name,
        }),
    }
