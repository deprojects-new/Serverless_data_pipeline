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
  default     = "serverless_data_pipeline"
}

variable "users" {
  description = "List of IAM users to create"
  type        = list(string)
  default     = ["your-user1", "your-user2", "your-user3"]
}



# Add these if missing:
variable "tf_state_bucket" { type = string } # e.g., "tfstate-872515279539"
variable "tf_lock_table" { type = string }   # e.g., "tf-locks"
variable "github_owner" { type = string }    # GitHub org/user
variable "github_repo" { type = string }     # Repository name

variable "enable_s3" {
  type    = bool
  default = true
}

variable "enable_lambda" {
  type    = bool
  default = false
}

variable "enable_glue" {
  type    = bool
  default = false
}

variable "enable_iam" {
  type    = bool
  default = false
}

variable "enable_sfn" {
  type    = bool
  default = false
}



