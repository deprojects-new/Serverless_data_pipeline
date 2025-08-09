variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
}

variable "data_lake_versioning" {
  description = "Enable versioning for the data lake bucket"
  type        = bool
  default     = true
}

variable "data_lake_lifecycle_days" {
  description = "Number of days to keep data in different tiers"
  type        = number
  default     = 365
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to trigger"
  type        = string
}

variable "lambda_permission_id" {
  description = "ID of the Lambda permission resource (for dependency)"
  type        = string
}