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

terraform {
  backend "s3" {
    bucket         = "tfstate-872515279539"
    key            = "serverless_data/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}

module "s3" {
  source = "./modules/s3"

  data_lake_bucket_name    = var.data_lake_bucket_name
  data_lake_versioning     = var.data_lake_versioning
  data_lake_lifecycle_days = var.data_lake_lifecycle_days
  environment              = var.environment
  project                  = var.project
  #lambda_function_arn      = module.lambda.lambda_function_arn
  #lambda_permission_id     = module.lambda.lambda_permission_id
}



