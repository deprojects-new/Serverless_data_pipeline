# Lambda function
resource "aws_lambda_function" "data_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = var.lambda_role_arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      RAW_BUCKET       = var.raw_bucket
      PROCESSED_BUCKET = var.processed_bucket
      ENVIRONMENT      = var.environment
    }
  }

  tags = {
    Name        = var.function_name
    Environment = var.environment
    Project     = var.project
  }
}

# Create a ZIP file of the Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_dir  = "${path.module}/lambda_code"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.function_name}-log-group"
    Environment = var.environment
    Project     = var.project
  }
}

# S3 trigger for Lambda
resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = var.s3_bucket

  lambda {
    lambda_function_arn = aws_lambda_function.data_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

# Lambda permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket}"
}

# CloudWatch Event Rule for scheduled execution (optional)
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "${var.function_name}-schedule"
  description         = "Schedule for Lambda function execution"
  schedule_expression = "rate(1 hour)"

  tags = {
    Name        = "${var.function_name}-schedule"
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.data_processor.arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
