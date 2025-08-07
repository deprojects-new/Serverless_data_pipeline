output "raw_storage_bucket_name" {
  description = "Name of the raw storage S3 bucket"
  value       = module.s3.raw_storage_bucket_name
}

output "raw_storage_bucket_arn" {
  description = "ARN of the raw storage S3 bucket"
  value       = module.s3.raw_storage_bucket_arn
}