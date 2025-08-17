# Bronze→Silver Job Outputs
output "bronze_to_silver_job_name" {
  description = "Name of the Bronze→Silver Glue job"
  value       = aws_glue_job.bronze_to_silver_job.name
}

output "bronze_to_silver_job_arn" {
  description = "ARN of the Bronze→Silver Glue job"
  value       = aws_glue_job.bronze_to_silver_job.arn
}

# Silver→Gold Job Outputs
output "silver_to_gold_job_name" {
  description = "Name of the Silver→Gold Glue job"
  value       = aws_glue_job.silver_to_gold_job.name
}

output "silver_to_gold_job_arn" {
  description = "ARN of the Silver→Gold Glue job"
  value       = aws_glue_job.silver_to_gold_job.arn
}

output "silver_crawler_name" {
  description = "Name of the Silver layer Glue crawler"
  value       = aws_glue_crawler.silver_crawler.name
}

output "silver_crawler_arn" {
  description = "ARN of the Silver layer Glue crawler"
  value       = aws_glue_crawler.silver_crawler.arn
}

output "database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.data_database.name
}

output "database_arn" {
  description = "ARN of the Glue database"
  value       = aws_glue_catalog_database.data_database.arn
}

# Log Group Outputs
output "bronze_silver_log_group_name" {
  description = "Name of the Bronze-Silver ETL log group"
  value       = aws_cloudwatch_log_group.bronze_silver_log_group.name
}

output "silver_gold_log_group_name" {
  description = "Name of the Silver-Gold ETL log group"
  value       = aws_cloudwatch_log_group.silver_gold_log_group.name
}

output "silver_crawler_log_group_name" {
  description = "Name of the Silver Crawler log group"
  value       = aws_cloudwatch_log_group.silver_crawler_log_group.name
}

# CloudWatch Alarm 
output "bronze_to_silver_job_failure_alarm_arn" {
  description = "ARN of the Bronze to Silver job failure alarm"
  value       = aws_cloudwatch_metric_alarm.bronze_to_silver_job_failure.arn
}

output "silver_to_gold_job_failure_alarm_arn" {
  description = "ARN of the Silver to Gold job failure alarm"
  value       = aws_cloudwatch_metric_alarm.silver_to_gold_job_failure.arn
}

output "silver_crawler_failure_alarm_arn" {
  description = "ARN of the Silver crawler failure alarm"
  value       = aws_cloudwatch_metric_alarm.silver_crawler_failure.arn
}

output "data_quality_bronze_silver_alarm_arn" {
  description = "ARN of the Bronze to Silver data quality alarm"
  value       = aws_cloudwatch_metric_alarm.data_quality_bronze_silver.arn
}

output "data_quality_silver_gold_alarm_arn" {
  description = "ARN of the Silver to Gold data quality alarm"
  value       = aws_cloudwatch_metric_alarm.data_quality_silver_gold.arn
}
