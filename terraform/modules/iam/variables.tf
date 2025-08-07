variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "glue_job_name" {
  description = "Name of the Glue ETL job"
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

variable "s3_lambda_code_bucket" {
  description = "Name of the S3 bucket for Lambda code"
  type        = string
}

variable "s3_glue_script_bucket" {
  description = "Name of the S3 bucket for Glue scripts"
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
