# AWS Region
AWS_REGION = us-east-2

# Lambda details
LAMBDA_FUNCTION_NAME = assignment5-ingest-lambda
LAMBDA_HANDLER       = lambda_function.lambda_handler
LAMBDA_RUNTIME       = python3.11
LAMBDA_TIMEOUT       = 900

# S3 buckets
S3_RAW_BUCKET = assignment5-raw-bucket

# Glue details
GLUE_JOB_NAME      = assignment5-etl-job
GLUE_CRAWLER_NAME  = assignment5-crawler
GLUE_DATABASE_NAME = assignment5-logdb

# Tags
ENVIRONMENT = production
PROJECT     = serverless-data-pipeline