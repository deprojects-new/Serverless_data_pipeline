
variable "database_name" {
  description = "Name of the Glue database"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
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

variable "db_prefix" {
  description = "Prefix for database name (e.g., 082898)"
  type        = string
  default     = "082898"
}

variable "local_glue_scripts_root" {
  description = "Local path (relative to terraform root) to Glue scripts"
  type        = string
  default     = "../src/glue_scripts"
}

variable "upload_scripts" {
  description = "Upload Glue ETL scripts to S3"
  type        = bool
  default     = true
}

variable "enable_alarms" {
  description = "Create CloudWatch metric alarms for Glue jobs"
  type        = bool
  default     = true
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

variable "glue_role_arn" {
  description = "ARN of the Glue execution role"
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

variable "sns_topic_arn" {
  description = "Existing SNS topic ARN to use for alarm actions (optional)"
  type        = string
  default     = ""
}
