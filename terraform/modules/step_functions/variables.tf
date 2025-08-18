variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "step_functions_role_arn" {
  description = "ARN of the Step Functions execution role"
  type        = string
}

variable "silver_crawler_name" {
  description = "Name of the Silver layer Glue crawler"
  type        = string
}

variable "bronze_to_silver_job_name" {
  description = "Name of the Bronze to Silver Glue job"
  type        = string
}

variable "silver_to_gold_job_name" {
  description = "Name of the Silver to Gold Glue job"
  type        = string
}
