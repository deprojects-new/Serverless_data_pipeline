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
module "s3" {
  source = "./modules/s3"

  raw_storage_bucket_name = var.s3_raw_bucket
  environment             = var.environment
  project                 = var.project
}
*/

terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "project-name/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"  # optional for locking
    encrypt        = true
  }
}

module "iam" {
  source          = "./modules/iam"
  users           = var.users
  s3_bucket_names = [var.s3_raw_bucket]
}

