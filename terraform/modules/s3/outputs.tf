output "raw_storage_bucket_name" {
  description = "Name of the raw storage S3 bucket"
  value       = aws_s3_bucket.raw_storage_bucket.bucket
}

output "raw_storage_bucket_arn" {
  description = "ARN of the raw storage S3 bucket"
  value       = aws_s3_bucket.raw_storage_bucket.arn
}