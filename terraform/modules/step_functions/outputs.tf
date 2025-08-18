output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.data_pipeline.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.data_pipeline.name
}

output "step_functions_log_group_name" {
  description = "Name of the Step Functions log group"
  value       = aws_cloudwatch_log_group.step_functions_log_group.name
}

# CloudWatch Alarm Outputs
output "step_functions_execution_duration_alarm_arn" {
  description = "ARN of the Step Functions execution duration alarm"
  value       = aws_cloudwatch_metric_alarm.step_functions_execution_duration.arn
}

output "step_functions_execution_failure_alarm_arn" {
  description = "ARN of the Step Functions execution failure alarm"
  value       = aws_cloudwatch_metric_alarm.step_functions_execution_failure.arn
}

output "step_functions_execution_timeout_alarm_arn" {
  description = "ARN of the Step Functions execution timeout alarm"
  value       = aws_cloudwatch_metric_alarm.step_functions_execution_timeout.arn
}
