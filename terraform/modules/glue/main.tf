# Glue Database
resource "aws_glue_catalog_database" "data_database" {
  name = "${var.db_prefix}-${var.environment}-${var.database_name}"

  tags = {
    Name        = "${var.db_prefix}-${var.environment}-${var.database_name}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_glue_crawler" "silver_crawler" {
  count         = var.enable_crawler ? 1 : 0
  name          = "${var.project}-${var.environment}-silver-crawler"
  database_name = aws_glue_catalog_database.data_database.name
  role          = var.glue_role_arn

  s3_target {
    path = "s3://${var.data_lake_bucket_name}/silver/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }

  table_prefix = "silver_"

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  schedule = var.crawler_schedule_cron

  tags = {
    Name        = "${var.project}-${var.environment}-silver-crawler"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-silver"
    ManagedBy   = "Terraform"
  }
}


# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "silver_crawler_log_group" {
  count             = var.enable_crawler ? 1 : 0
  name              = "/aws-glue/crawlers/${var.project}-${var.environment}-silver-crawler"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project}-${var.environment}-silver-crawler-logs"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Bronze to Silver Job
resource "aws_glue_job" "bronze_to_silver_job" {
  name     = "${var.project}-bronze-to-silver-job"
  role_arn = var.glue_role_arn

  command {
    script_location = "s3://${var.data_lake_bucket_name}/glue_scripts/bronze_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--project"                          = var.project
    "--bucket"                           = var.data_lake_bucket_name
    "--database"                         = aws_glue_catalog_database.data_database.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--enable-job-insights"              = "true"
    "--enable-continuous-log-filter"     = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.bronze_silver_log_group.name
    "--continuous-log-logStreamPrefix"   = "bronze-silver-"
  }

  glue_version      = var.glue_version
  number_of_workers = var.number_of_workers
  worker_type       = var.worker_type
  max_retries       = 1
  timeout           = 30




  tags = {
    Name  = "${var.project}-bronze-to-silver"
    Layer = "medallion-silver"
  }
}

# Silver to Gold Job  
resource "aws_glue_job" "silver_to_gold_job" {
  name     = "${var.project}-silver-to-gold-job"
  role_arn = var.glue_role_arn

  command {
    script_location = "s3://${var.data_lake_bucket_name}/glue_scripts/silver_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--project"                          = var.project
    "--bucket"                           = var.data_lake_bucket_name
    "--database"                         = aws_glue_catalog_database.data_database.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--enable-job-insights"              = "true"
    "--enable-continuous-log-filter"     = "true"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.silver_gold_log_group.name
    "--continuous-log-logStreamPrefix"   = "silver-gold-"
  }

  glue_version      = var.glue_version
  number_of_workers = var.number_of_workers
  worker_type       = var.worker_type
  max_retries       = 1
  timeout           = 30

  tags = {
    Name  = "${var.project}-silver-to-gold"
    Layer = "medallion-gold"
  }
}



# Upload Bronze→Silver script
resource "aws_s3_object" "bronze_to_silver_script" {
  count  = var.upload_scripts ? 1 : 0
  bucket = var.data_lake_bucket_name
  key    = "glue_scripts/bronze_silver.py"
  source = "${path.root}/${var.local_glue_scripts_root}/bronze_silver.py"
  etag   = filemd5("${path.root}/${var.local_glue_scripts_root}/bronze_silver.py")

  tags = {
    Name  = "bronze-to-silver-script"
    Layer = "medallion-silver"
  }
}

# Upload Silver→Gold script
resource "aws_s3_object" "silver_to_gold_script" {
  count  = var.upload_scripts ? 1 : 0
  bucket = var.data_lake_bucket_name
  key    = "glue_scripts/silver_gold.py"
  source = "${path.root}/${var.local_glue_scripts_root}/silver_gold.py"
  etag   = filemd5("${path.root}/${var.local_glue_scripts_root}/silver_gold.py")

  tags = {
    Name  = "silver-to-gold-script"
    Layer = "medallion-gold"
  }
}

# Professional Glue Job Log Groups
resource "aws_cloudwatch_log_group" "bronze_silver_log_group" {
  name              = "/aws-glue/jobs/${var.project}-${var.environment}-bronze-silver"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project}-${var.environment}-bronze-silver-logs"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}


resource "aws_cloudwatch_log_group" "silver_gold_log_group" {
  name              = "/aws-glue/jobs/${var.project}-${var.environment}-silver-gold"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project}-${var.environment}-silver-gold-logs"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}



# Data Quality Alarms
resource "aws_cloudwatch_metric_alarm" "data_quality_bronze_silver" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.environment}-data-quality-bronze-silver"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "glue.driver.aggregate.recordsRead"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = var.dq_threshold_bronze_silver
  alarm_description   = "Low records processed by Bronze->Silver job"
  alarm_actions       = []

  dimensions = {
    JobName = aws_glue_job.bronze_to_silver_job.name
    Type    = "driver"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-data-quality-bronze-silver"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-data-quality"
  }
}

resource "aws_cloudwatch_metric_alarm" "data_quality_silver_gold" {
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${var.project}-${var.environment}-data-quality-silver-gold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "glue.driver.aggregate.recordsRead"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = var.dq_threshold_silver_gold
  alarm_description   = "Low records processed by Silver->Gold job"
  alarm_actions       = []

  dimensions = {
    JobName = aws_glue_job.silver_to_gold_job.name
    Type    = "driver"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-data-quality-silver-gold"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-data-quality"
  }
}