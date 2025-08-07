variable "users" {
  description = "List of IAM users to create"
  type        = list(string)
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to allow access"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "s3_raw_bucket" {
  description = "Name of the S3 bucket for raw data"
  type        = string
}

variable "s3_processed_bucket" {
  description = "Name of the S3 bucket for processed data"
  type        = string
}