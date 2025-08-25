# AWS Region
aws_region = "us-east-2"


# Your existing fields for your stack:
# Data Lake Configuration
data_lake_bucket_name = "sdp-prod-datalake-082898"
project               = "serverless-data-pipeline"
environment           = "prod"

# Lifecycle Configuration
data_lake_versioning     = true
data_lake_lifecycle_days = 365 # Longer retention for production environment

# OIDC/IAM variables:
tf_state_bucket = "tfstate-872515279539"
tf_lock_table   = "tf-locks"
github_owner    = "deprojects-new"
github_repo     = "Serverless_data_pipeline"

database_name         = "analytics"
db_prefix             = "082898"
enable_crawler        = true
crawler_schedule_cron = "cron(0 */4 * * ? *)"
log_retention_days    = 30
glue_version          = "4.0"
worker_type           = "G.1X"
number_of_workers     = 2
upload_scripts        = true


dq_threshold_bronze_silver = 100
dq_threshold_silver_gold   = 50

enable_lambda = false
enable_sfn    = false

enable_ci_bootstrap = true
