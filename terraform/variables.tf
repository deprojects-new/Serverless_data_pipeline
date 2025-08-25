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



variable "glue_role_arn" {
  description = "ARN of the Glue execution role"
  type        = string
}

variable "database_name" {
  description = "Logical suffix for Glue database (e.g., analytics)"
  type        = string
}

variable "db_prefix" {
  description = "Prefix for database name (e.g., 082898)"
  type        = string
  default     = "082898"
}

variable "enable_crawler" {
  description = "Create and manage the silver Glue crawler"
  type        = bool
  default     = true
}

variable "crawler_schedule_cron" {
  description = "Cron for Glue crawler schedule"
  type        = string
  default     = "cron(0 */4 * * ? *)"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for Glue logs"
  type        = number
  default     = 30
}

variable "glue_version" {
  description = "Glue version for jobs"
  type        = string
  default     = "4.0"
}

variable "worker_type" {
  description = "Worker type: G.1X, G.2X, G.4X, G.8X"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Workers per job"
  type        = number
  default     = 2
}

variable "dq_threshold_bronze_silver" {
  description = "Minimum records read for Bronze->Silver"
  type        = number
  default     = 100
}

variable "dq_threshold_silver_gold" {
  description = "Minimum records read for Silver->Gold"
  type        = number
  default     = 50
}

variable "enable_alarms" {
  description = "Create CloudWatch metric alarms for Glue jobs"
  type        = bool
  default     = true
}

variable "upload_scripts" {
  description = "Upload Glue ETL scripts to S3"
  type        = bool
  default     = true
}

variable "local_glue_scripts_root" {
  description = "Local path (relative to terraform root) to Glue scripts"
  type        = string
  default     = "../src/glue_scripts"
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

variable "enable_ci_bootstrap" {
  description = "Create/own the GitHub OIDC provider and CI roles/policies"
  type        = bool
  default     = false
}

