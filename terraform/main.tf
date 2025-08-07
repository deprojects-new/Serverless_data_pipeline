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

  raw_storage_bucket_name      = var.s3_raw_bucket
  processed_storage_bucket_name = var.s3_processed_bucket
  environment                  = var.environment
  project                      = var.project
}



module "iam" {
  source              = "./modules/iam"
  users               = var.users
  s3_bucket_names     = [var.s3_raw_bucket, var.s3_processed_bucket]
  s3_raw_bucket       = var.s3_raw_bucket
  s3_processed_bucket = var.s3_processed_bucket
  environment         = var.environment
  project             = var.project
}

module "lambda" {
  source                    = "./modules/lambda"
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  s3_raw_bucket            = var.s3_raw_bucket
  environment              = var.environment
  project                  = var.project
}
