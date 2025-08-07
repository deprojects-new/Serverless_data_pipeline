variable "job_name" {
  description = "Name of the Glue ETL job"
  type        = string
}

variable "crawler_name" {
  description = "Name of the Glue crawler"
  type        = string
}

variable "database_name" {
  description = "Name of the Glue database"
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
