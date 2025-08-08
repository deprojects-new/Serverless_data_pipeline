# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}



#Data Lake Configuration
variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
  default     = "assignment5-data-lake"
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
