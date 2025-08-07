variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
}

variable "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name for Lambda code"
  type        = string
}

variable "raw_bucket" {
  description = "S3 bucket name for raw data"
  type        = string
}

variable "processed_bucket" {
  description = "S3 bucket name for processed data"
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
