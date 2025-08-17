# Lambda function
resource "aws_lambda_function" "data_pipeline_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project}-data-pipeline-lambda"
  role            = var.lambda_execution_role_arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300  # 5 minutes
  memory_size     = 128

  #  logging configuration to use custom log group
  logging_config {
    log_group = aws_cloudwatch_log_group.lambda_log_group.name
    log_format = "Text"
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT     = var.project
      BRONZE_TO_SILVER_JOB_NAME = var.bronze_to_silver_job_name
      SILVER_TO_GOLD_JOB_NAME = var.silver_to_gold_job_name
      STATE_MACHINE_ARN = var.state_machine_arn
      LOG_GROUP_NAME = aws_cloudwatch_log_group.lambda_log_group.name
    }
  }

  tags = {
    Name        = "${var.project}-data-pipeline-lambda"
    Environment = var.environment
    Project     = var.project
    Purpose     = "data-pipeline-trigger"
  }
}

#  ZIP file from Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../src/lambda_code"
  output_path = "${path.root}/../src/lambda_function.zip"
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "s3_invoke_lambda" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_pipeline_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.data_lake_bucket_name}"
}

# Professional Lambda Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/assignment5-lambda"
  retention_in_days = 0  # Never expire - matches AWS Lambda default behavior

  tags = {
    Name        = "assignment5-lambda-logs"
    Environment = var.environment
    Project     = var.project
    Purpose     = "lambda-execution-logs"
    ManagedBy   = "terraform"
  }
}

# Data source to reference existing default log group to look up existing log group 
data "aws_cloudwatch_log_group" "default_lambda_log_group" {
  name = "/aws/lambda/${var.project}-data-pipeline-lambda"
}


