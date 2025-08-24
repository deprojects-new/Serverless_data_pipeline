output "data_lake_bucket_name" {
  description = "Name of the data lake S3 bucket"
  value       = module.s3.data_lake_bucket_name
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  value       = module.s3.data_lake_bucket_arn
}

output "data_lake_bucket_id" {
  description = "ID of the data lake S3 bucket"
  value       = module.s3.data_lake_bucket_id
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

output "glue_execution_role_arn" {
  description = "ARN of the Glue execution role"
  value       = module.iam.glue_execution_role_arn
}

output "bronze_to_silver_job_name" {
  description = "Name of the Bronze→Silver Glue job"
  value       = module.glue.bronze_to_silver_job_name
}

output "bronze_to_silver_job_arn" {
  description = "ARN of the Bronze→Silver Glue job"
  value       = module.glue.bronze_to_silver_job_arn
}

output "silver_to_gold_job_name" {
  description = "Name of the Silver→Gold Glue job"
  value       = module.glue.silver_to_gold_job_name
}

output "silver_to_gold_job_arn" {
  description = "ARN of the Silver→Gold Glue job"
  value       = module.glue.silver_to_gold_job_arn
}

output "glue_silver_crawler_name" {
  description = "Name of the Silver layer Glue crawler"
  value       = module.glue.silver_crawler_name
}

output "glue_silver_crawler_arn" {
  description = "ARN of the Silver layer Glue crawler"
  value       = module.glue.silver_crawler_arn
}

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = module.glue.database_name
}

output "glue_database_arn" {
  description = "ARN of the Glue database"
  value       = module.glue.database_arn
}

# Log Group Outputs
output "lambda_log_group_name" {
  description = "Name of the Lambda log group"
  value       = module.lambda.lambda_log_group_name
}



output "step_functions_log_group_name" {
  description = "Name of the Step Functions log group"
  value       = module.step_functions.step_functions_log_group_name
}

output "bronze_silver_log_group_name" {
  description = "Name of the Bronze-Silver ETL log group"
  value       = module.glue.bronze_silver_log_group_name
}

output "silver_gold_log_group_name" {
  description = "Name of the Silver-Gold ETL log group"
  value       = module.glue.silver_gold_log_group_name
}

output "silver_crawler_log_group_name" {
  description = "Name of the Silver Crawler log group"
  value       = module.glue.silver_crawler_log_group_name
}



output "silver_crawler_failure_alarm_arn" {
  description = "ARN of the Silver crawler failure alarm"
  value       = module.step_functions.crawler_failure_alarm_arn
}

output "data_quality_bronze_silver_alarm_arn" {
  description = "ARN of the Bronze to Silver data quality alarm"
  value       = module.glue.data_quality_bronze_silver_alarm_arn
}

output "data_quality_silver_gold_alarm_arn" {
  description = "ARN of the Silver to Gold data quality alarm"
  value       = module.glue.data_quality_silver_gold_alarm_arn
}

output "step_functions_execution_duration_alarm_arn" {
  description = "ARN of the Step Functions execution duration alarm"
  value       = module.step_functions.step_functions_execution_duration_alarm_arn
}

output "step_functions_execution_failure_alarm_arn" {
  description = "ARN of the Step Functions execution failure alarm"
  value       = module.step_functions.step_functions_execution_failure_alarm_arn
}

 