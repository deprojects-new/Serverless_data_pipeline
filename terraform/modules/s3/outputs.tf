output "raw_storage_bucket_name" {
  description = "Name of the raw storage S3 bucket"
  value       = aws_s3_bucket.raw_storage_bucket.bucket
}

output "raw_storage_bucket_arn" {
  description = "ARN of the raw storage S3 bucket"
  value       = aws_s3_bucket.raw_storage_bucket.arn
}

output "processed_storage_bucket_name" {
  description = "Name of the processed storage S3 bucket"
  value       = aws_s3_bucket.processed_storage_bucket.bucket
}

output "processed_storage_bucket_arn" {
  description = "ARN of the processed storage S3 bucket"
  value       = aws_s3_bucket.processed_storage_bucket.arn
}