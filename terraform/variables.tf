# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
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
