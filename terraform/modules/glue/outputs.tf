output "job_name" {
  description = "Name of the Glue ETL job"
  value       = aws_glue_job.etl_job.name
}

output "job_arn" {
  description = "ARN of the Glue ETL job"
  value       = aws_glue_job.etl_job.arn
}

output "crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.data_crawler.name
}

output "crawler_arn" {
  description = "ARN of the Glue crawler"
  value       = aws_glue_crawler.data_crawler.arn
}

output "database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.data_database.name
}

output "database_arn" {
  description = "ARN of the Glue database"
  value       = aws_glue_catalog_database.data_database.arn
}
