variable "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  type        = string
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


variable "bronze_to_silver_job_name" {
  description = "Name of the Bronze→Silver job"
  type        = string
}

variable "silver_to_gold_job_name" {
  description = "Name of the Silver→Gold job"  
  type        = string
}

variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  type        = string
}