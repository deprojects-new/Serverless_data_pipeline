# Glue Database
resource "aws_glue_catalog_database" "data_database" {
  name = var.database_name

  tags = {
    Name        = var.database_name
    Environment = var.environment
    Project     = var.project
  }
}

# Glue Crawler
resource "aws_glue_crawler" "data_crawler" {
  name          = var.crawler_name
  database_name = aws_glue_catalog_database.data_database.name
  role          = var.glue_role_arn

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/raw/"
  }

  schedule = "cron(0 */6 * * ? *)" # Run every 6 hours

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  tags = {
    Name        = var.crawler_name
    Environment = var.environment
    Project     = var.project
  }
}

# Glue Job
resource "aws_glue_job" "etl_job" {
  name     = var.job_name
  role_arn = var.glue_role_arn

  command {
    script_location = "s3://${var.data_lake_bucket_name}/glue_scripts/etl_script.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--raw_path"                         = "s3://${var.data_lake_bucket_name}/raw/"
    "--processed_path"                    = "s3://${var.data_lake_bucket_name}/processed/"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  max_retries = 0
  timeout     = 2880 # 48 minutes

  tags = {
    Name        = var.job_name
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Log Group for Glue
resource "aws_cloudwatch_log_group" "glue_log_group" {
  name              = "/aws-glue/jobs/${var.job_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.job_name}-log-group"
    Environment = var.environment
    Project     = var.project
  }
}



# Glue Security Configuration
resource "aws_glue_security_configuration" "glue_security_config" {
  name = "${var.job_name}-security-config"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "DISABLED"
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }

    s3_encryption {
      s3_encryption_mode = "SSE-S3"
    }
  }
}

resource "aws_s3_object" "etl_script" {
  bucket = var.data_lake_bucket_name
  key    = "glue_scripts/etl_script.py"
  source = "${path.root}/../src/glue_scripts/etl_script.py"
  etag   = filemd5("${path.root}/../src/glue_scripts/etl_script.py")
}