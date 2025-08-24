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