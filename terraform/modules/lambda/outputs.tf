output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.data_pipeline_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.data_pipeline_lambda.arn
}

output "lambda_permission_id" {
  description = "ID of the Lambda permission resource"
  value       = aws_lambda_permission.s3_invoke_lambda.id
}