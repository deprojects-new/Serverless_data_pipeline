variable "raw_storage_bucket_name" {
  description = "Name of the S3 bucket for raw data storage"
  type        = string
}

variable "processed_storage_bucket_name" {
  description = "Name of the S3 bucket for processed data storage"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}