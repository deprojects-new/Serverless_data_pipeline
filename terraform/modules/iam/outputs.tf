

#output "lambda_execution_role_arn" {
# description = "ARN of the Lambda execution role"
# value       = aws_iam_role.lambda_execution_role.arn
#}

output "glue_execution_role_arn" {
  description = "ARN of the Glue execution role"
  value       = aws_iam_role.glue_execution_role.arn
}

#output "step_functions_execution_role_arn" {
# description = "ARN of the Step Functions execution role"
#value       = aws_iam_role.step_functions_execution_role.arn
#}

