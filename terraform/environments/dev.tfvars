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

# Lifecycle Configuration
data_lake_versioning     = true
data_lake_lifecycle_days = 90 # Shorter retention for dev environment


database_name      = "analytics"
db_prefix          = "082898"
enable_crawler     = true
log_retention_days = 30

dq_threshold_bronze_silver = 50
dq_threshold_silver_gold   = 25

enable_lambda = false
enable_iam    = false
enable_sfn    = false

enable_ci_bootstrap = false
