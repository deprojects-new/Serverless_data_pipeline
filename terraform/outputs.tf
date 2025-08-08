output "raw_storage_bucket_name" {
  description = "Name of the raw storage S3 bucket"
  value       = module.s3.raw_storage_bucket_name
}

output "raw_storage_bucket_arn" {
  description = "ARN of the raw storage S3 bucket"
  value       = module.s3.raw_storage_bucket_arn
}

output "processed_storage_bucket_name" {
  description = "Name of the processed storage S3 bucket"
  value       = module.s3.processed_storage_bucket_name
}

output "processed_storage_bucket_arn" {
  description = "ARN of the processed storage S3 bucket"
  value       = module.s3.processed_storage_bucket_arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

output "glue_execution_role_arn" {
  description = "ARN of the Glue execution role"
  value       = module.iam.glue_execution_role_arn
}

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = module.glue.job_name
}

output "glue_job_arn" {
  description = "ARN of the Glue ETL job"
  value       = module.glue.job_arn
}

output "glue_crawler_name" {
  description = "Name of the Glue crawler"
  value       = module.glue.crawler_name
}

output "glue_crawler_arn" {
  description = "ARN of the Glue crawler"
  value       = module.glue.crawler_arn
}

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = module.glue.database_name
}

output "glue_database_arn" {
  description = "ARN of the Glue database"
  value       = module.glue.database_arn
}