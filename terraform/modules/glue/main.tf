# Glue Database
resource "aws_glue_catalog_database" "data_database" {
  name = "${var.project}-${var.database_name}"

  tags = {
    Name        = var.database_name
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_glue_crawler" "silver_crawler" {
  name          = "${var.project}-silver-crawler"
  database_name = aws_glue_catalog_database.data_database.name
  role          = var.glue_role_arn
  
  s3_target {
    path = "s3://${var.data_lake_bucket_name}/silver/"
  }
  
  # Configure for Parquet data
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }
  
  # prefix for silver layer
  table_prefix = "silver_"
  
  # Recrawl policy - run when new data is detected
  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
  
  # Configuration for better performance
  configuration = jsonencode({
    "Version" = 1.0
    "CrawlerOutput" = {
      "Partitions" = {
        "AddOrUpdateBehavior" = "InheritFromTable"
      }
      "Tables" = {
        "AddOrUpdateBehavior" = "MergeNewColumns"
      }
    }
  })
  
  # Schedule - to keep the metadata updated
  schedule = "cron(0 */6 * * ? *)"  # Every 6 hours
  
  tags = {
    Name  = "${var.project}-silver-crawler"
    Layer = "medallion-silver"
  }
}


# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "silver_crawler_log_group" {
  name              = "/aws-glue/crawlers/assignment5-silver-crawler"
  retention_in_days = 0
  
  tags = {
    Name        = "${var.project}-silver-crawler-logs"
    Environment = var.environment
    Project     = var.project
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
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-enable"
    "--project"             = var.project
    "--bucket"              = var.data_lake_bucket_name
    "--database"            = aws_glue_catalog_database.data_database.name
    "--continuous-log-logGroup" = aws_cloudwatch_log_group.bronze_silver_log_group.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"      = "true"
    "--enable-spark-ui"     = "true"
    "--enable-job-insights" = "true"
    "--enable-spark-ui"     = "true"
    "--enable-metrics"      = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter" = "true"
    "--continuous-log-logGroup" = aws_cloudwatch_log_group.bronze_silver_log_group.name
    "--continuous-log-logStreamPrefix" = "bronze-silver-"
  }

  glue_version = "4.0"
  max_retries  = 1
  timeout      = 30  # 30 minutes max




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
    "--job-language"        = "python"
    "--job-bookmark-option" = "job-bookmark-enable"
    "--project"             = var.project
    "--bucket"              = var.data_lake_bucket_name
    "--database"            = aws_glue_catalog_database.data_database.name
    "--continuous-log-logGroup" = aws_cloudwatch_log_group.silver_gold_log_group.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"      = "true"
    "--enable-spark-ui"     = "true"
    "--enable-job-insights" = "true"
    "--enable-spark-ui"     = "true"
    "--enable-metrics"      = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter" = "true"
    "--continuous-log-logGroup" = aws_cloudwatch_log_group.silver_gold_log_group.name
    "--continuous-log-logStreamPrefix" = "silver-gold-"
  }

  glue_version = "4.0"
  max_retries  = 1
  timeout      = 30 


  tags = {
    Name  = "${var.project}-silver-to-gold"
    Layer = "medallion-gold"
  }
}



# Upload Bronze→Silver script
resource "aws_s3_object" "bronze_to_silver_script" {
  bucket = var.data_lake_bucket_name
  key    = "glue_scripts/bronze_silver.py"
  source = "${path.root}/../src/glue_scripts/bronze_silver.py"
  etag   = filemd5("${path.root}/../src/glue_scripts/bronze_silver.py")

  tags = {
    Name = "bronze-to-silver-script"
    Layer = "medallion-silver"
  }
}

# Upload Silver→Gold script
resource "aws_s3_object" "silver_to_gold_script" {
  bucket = var.data_lake_bucket_name
  key    = "glue_scripts/silver_gold.py"
  source = "${path.root}/../src/glue_scripts/silver_gold.py"
  etag   = filemd5("${path.root}/../src/glue_scripts/silver_gold.py")

  tags = {
    Name = "silver-to-gold-script"
    Layer = "medallion-gold"
  }
}

# Professional Glue Job Log Groups
resource "aws_cloudwatch_log_group" "bronze_silver_log_group" {
  name              = "/aws-glue/jobs/assignment5-bronze-silver"
  retention_in_days = 0  # Never expire - matches AWS Glue default behavior

  tags = {
    Name        = "assignment5-bronze-silver-logs"
    Environment = var.environment
    Project     = var.project
    Purpose     = "bronze-to-silver-etl-logs"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "silver_gold_log_group" {
  name              = "/aws-glue/jobs/assignment5-silver-gold"
  retention_in_days = 0  # Never expire - matches AWS Glue default behavior

  tags = {
    Name        = "assignment5-silver-gold-logs"
    Environment = var.environment
    Project     = var.project
    Purpose     = "silver-to-gold-etl-logs"
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarms for Glue Jobs and Crawler
resource "aws_cloudwatch_metric_alarm" "bronze_to_silver_job_failure" {
  alarm_name          = "${var.project}-bronze-to-silver-job-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.bytesRead"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when Bronze to Silver job fails or has issues"
  alarm_actions       = []  # Will add SNS topic later
  
  dimensions = {
    JobName = aws_glue_job.bronze_to_silver_job.name
    Type    = "driver"
  }

  tags = {
    Name        = "${var.project}-bronze-silver-job-failure-alarm"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-bronze-silver"
  }
}

resource "aws_cloudwatch_metric_alarm" "silver_to_gold_job_failure" {
  alarm_name          = "${var.project}-silver-to-gold-job-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.bytesRead"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when Silver to Gold job fails or has issues"
  alarm_actions       = []  # Will add SNS topic later
  
  dimensions = {
    JobName = aws_glue_job.silver_to_gold_job.name
    Type    = "driver"
  }

  tags = {
    Name        = "${var.project}-silver-gold-job-failure-alarm"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-silver-gold"
  }
}

resource "aws_cloudwatch_metric_alarm" "silver_crawler_failure" {
  alarm_name          = "${var.project}-silver-crawler-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.crawler.running"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alarm when Silver crawler fails or gets stuck"
  alarm_actions       = []  # Will add SNS topic later
  
  dimensions = {
    CrawlerName = aws_glue_crawler.silver_crawler.name
  }

  tags = {
    Name        = "${var.project}-silver-crawler-failure-alarm"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-silver-crawler"
  }
}

# Data Quality Alarms
resource "aws_cloudwatch_metric_alarm" "data_quality_bronze_silver" {
  alarm_name          = "${var.project}-data-quality-bronze-silver"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "glue.driver.aggregate.recordsRead"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 100  # Alert if less than 100 records processed
  alarm_description   = "Alarm when Bronze to Silver job processes very few records (potential data issue)"
  alarm_actions       = []  # Will add SNS topic later
  
  dimensions = {
    JobName = aws_glue_job.bronze_to_silver_job.name
    Type    = "driver"
  }

  tags = {
    Name        = "${var.project}-data-quality-bronze-silver-alarm"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-data-quality"
  }
}

resource "aws_cloudwatch_metric_alarm" "data_quality_silver_gold" {
  alarm_name          = "${var.project}-data-quality-silver-gold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "glue.driver.aggregate.recordsRead"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 50   # Alert if less than 50 records processed
  alarm_description   = "Alarm when Silver to Gold job processes very few records (potential data issue)"
  alarm_actions       = []  # Will add SNS topic later
  
  dimensions = {
    JobName = aws_glue_job.silver_to_gold_job.name
    Type    = "driver"
  }

  tags = {
    Name        = "${var.project}-data-quality-silver-gold-alarm"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-data-quality"
  }
}