output "iam_user_names" {
  value = [for user in aws_iam_user.users : user.name]
}

output "data_engineers_group" {
  value = aws_iam_group.data_engineers.name
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "glue_execution_role_arn" {
  description = "ARN of the Glue execution role"
  value       = aws_iam_role.glue_execution_role.arn
}

