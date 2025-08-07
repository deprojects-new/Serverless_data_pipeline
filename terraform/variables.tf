# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

# Lambda Configuration
variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "assignment5-ingest-lambda"
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900
}

# S3 Configuration
variable "s3_raw_bucket" {
  description = "Name of the S3 bucket for raw data"
  type        = string
  default     = "assignment5-raw-bucket"
}

variable "s3_processed_bucket" {
  description = "Name of the S3 bucket for processed data"
  type        = string
  default     = "assignment5-processed-bucket"
}

variable "s3_lambda_code_bucket" {
  description = "Name of the S3 bucket for Lambda code"
  type        = string
  default     = "assignment5-lambda-code"
}

variable "s3_glue_script_bucket" {
  description = "Name of the S3 bucket for Glue scripts"
  type        = string
  default     = "assignment5-glue-script"
}

# Glue Configuration
variable "glue_job_name" {
  description = "Name of the Glue ETL job"
  type        = string
  default     = "assignment5-etl-job"
}

variable "glue_crawler_name" {
  description = "Name of the Glue crawler"
  type        = string
  default     = "assignment5-crawler"
}

variable "glue_database_name" {
  description = "Name of the Glue database"
  type        = string
  default     = "assignment5-logdb"
}

# Tags
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "serverless-data-pipeline"
}

variable "users" {
  description = "List of IAM users to create"
  type        = list(string)
  default     = ["your-user1", "your-user2", "your-user3"]
}
