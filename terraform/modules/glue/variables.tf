
variable "database_name" {
  description = "Name of the Glue database"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
}



variable "glue_role_arn" {
  description = "ARN of the Glue execution role"
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
