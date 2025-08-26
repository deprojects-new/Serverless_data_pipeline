# Configure AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "Terraform"
    }
  }
}

/*
terraform {
  backend "s3" {
    bucket         = "tfstate-872515279539"
    key            = "serverless_data/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
*/

module "s3" {
  source                   = "./modules/s3"
  data_lake_bucket_name    = var.data_lake_bucket_name
  data_lake_versioning     = var.data_lake_versioning
  data_lake_lifecycle_days = var.data_lake_lifecycle_days
  environment              = var.environment
  project                  = var.project
}

# module "glue" {
#   source = "./modules/glue"
#   data_lake_bucket_name = var.data_lake_bucket_name
#   glue_role_arn         = module.iam.glue_execution_role_arn
#   environment           = var.environment
#   project               = var.project
#   database_name         = var.database_name
#   db_prefix             = var.db_prefix
#   enable_crawler        = var.enable_crawler
#   crawler_schedule_cron = var.crawler_schedule_cron
#   log_retention_days    = var.log_retention_days
#   glue_version      = var.glue_version
#   worker_type       = var.worker_type
#   number_of_workers = var.number_of_workers
#   dq_threshold_bronze_silver = var.dq_threshold_bronze_silver
#   dq_threshold_silver_gold   = var.dq_threshold_silver_gold
#   enable_alarms              = var.enable_alarms
#   upload_scripts          = var.upload_scripts
#   local_glue_scripts_root = var.local_glue_scripts_root
# }

# module "iam" {
#   source                = "./modules/iam"
#   environment           = var.environment
#   project               = var.project
#   users                 = []
#   data_lake_bucket_name = var.data_lake_bucket_name
# }
