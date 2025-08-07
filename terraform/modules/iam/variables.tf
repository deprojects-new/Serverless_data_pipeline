variable "users" {
  description = "List of IAM users to create"
  type        = list(string)
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to allow access"
  type        = list(string)
}