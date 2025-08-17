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
  lambda_function_arn        = module.lambda.lambda_function_arn
  lambda_permission_id       = module.lambda.lambda_permission_id
}



module "iam" {
  source              = "./modules/iam"
  users               = var.users
  data_lake_bucket_name = var.data_lake_bucket_name
  environment         = var.environment
  project             = var.project
}

module "glue" {
  source              = "./modules/glue"
  data_lake_bucket_name = var.data_lake_bucket_name
  glue_role_arn       = module.iam.glue_execution_role_arn
  environment         = var.environment
  project             = var.project
  database_name       = "assignment5_data_database"
}

module "step_functions" {
  source                    = "./modules/step_functions"
  project                   = var.project
  environment               = var.environment
  step_functions_role_arn   = module.iam.step_functions_execution_role_arn
  silver_crawler_name       = module.glue.silver_crawler_name
  bronze_to_silver_job_name = module.glue.bronze_to_silver_job_name
  silver_to_gold_job_name   = module.glue.silver_to_gold_job_name
}

module "lambda" {
  source                    = "./modules/lambda"
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  data_lake_bucket_name    = var.data_lake_bucket_name
  environment              = var.environment
  project                  = var.project
  bronze_to_silver_job_name = module.glue.bronze_to_silver_job_name
  silver_to_gold_job_name   = module.glue.silver_to_gold_job_name
  state_machine_arn        = module.step_functions.state_machine_arn
}