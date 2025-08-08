variable "users" {
  description = "List of IAM users to create"
  type        = list(string)
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
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
