# Lambda function
resource "aws_lambda_function" "data_pipeline_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "assignment5-data-pipeline-lambda"
  role            = var.lambda_execution_role_arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300  # 5 minutes
  memory_size     = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT     = var.project
    }
  }

  tags = {
    Name        = "assignment5-data-pipeline-lambda"
    Environment = var.environment
    Project     = var.project
    Purpose     = "data-pipeline-trigger"
  }
}

# Create ZIP file from Lambda code
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
  source_arn    = "arn:aws:s3:::${var.s3_raw_bucket}"
}



# Note: CloudWatch Event rules removed for now - we'll use S3 triggers instead
