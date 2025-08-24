# AWS Region
aws_region = "us-east-2"


# Your existing fields for your stack:


# OIDC/IAM variables:
tf_state_bucket = "tfstate-872515279539"
tf_lock_table   = "tf-locks"
github_owner    = "deprojects-new"
github_repo     = "Serverless_data_pipeline"


# Data Lake Configuration
data_lake_bucket_name = "sdp-dev-datalake-082898"
project               = "serverless-data-pipeline"
environment           = "dev"

enable_lambda = false
enable_glue   = false
enable_iam    = false
enable_sfn    = false

