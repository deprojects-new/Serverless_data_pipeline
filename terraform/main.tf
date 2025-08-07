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

  raw_storage_bucket_name = var.s3_raw_bucket
  environment             = var.environment
  project                 = var.project
}