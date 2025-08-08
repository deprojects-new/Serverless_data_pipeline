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


module "s3" {
  source = "./modules/s3"

  data_lake_bucket_name      = var.data_lake_bucket_name
  data_lake_versioning       = var.data_lake_versioning
  data_lake_lifecycle_days   = var.data_lake_lifecycle_days
  environment                = var.environment
  project                    = var.project
}



module "iam" {
  source              = "./modules/iam"
  users               = var.users
  data_lake_bucket_name = var.data_lake_bucket_name
  environment         = var.environment
  project             = var.project
}

module "lambda" {
  source                    = "./modules/lambda"
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  data_lake_bucket_name    = var.data_lake_bucket_name
  environment              = var.environment
  project                  = var.project
}

module "glue" {
  source              = "./modules/glue"
  database_name       = "assignment5-data-database"
  crawler_name        = "assignment5-crawler"
  job_name            = "assignment5-etl-job"
  glue_role_arn       = module.iam.glue_execution_role_arn
  data_lake_bucket_name = var.data_lake_bucket_name
  environment         = var.environment
  project             = var.project
}
