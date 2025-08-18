# Step Functions State Machine for Data Pipeline
resource "aws_sfn_state_machine" "data_pipeline" {
  name     = "${var.project}-data-pipeline"
  role_arn = var.step_functions_role_arn

  definition = jsonencode({
    Comment = "Serverless Data Pipeline Orchestration "
    StartAt = "SetExecutionContext"
    
    States = {
      # Step 1: Set execution context for Glue jobs
      SetExecutionContext = {
        Type = "Pass"
        Parameters = {
          execution_name = "$$.Execution.Name"
          execution_start_time = "$$.Execution.StartTime"
          trigger_time = "$.trigger_time"
          bucket = "$.bucket"
          key = "$.key"
          size = "$.size"
          data_layer = "$.data_layer"
          environment = "$.environment"
          correlation_id = "$$.Execution.Name"
          data_volume_mb = "States.MathDivide($.size, 1048576)"
        }
        Next = "StartBronzeToSilverJob"
      }

      # Step 2: Start Bronze to Silver Job
      StartBronzeToSilverJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startJobRun"
        Parameters = {
          JobName = var.bronze_to_silver_job_name
        }
        ResultPath = "$.BronzeToSilverResult"
        Retry = [
          {
            ErrorEquals = ["States.TaskFailed"]
            IntervalSeconds = 60
            MaxAttempts = 3
            BackoffRate = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "BronzeToSilverFailed"
          }
        ]
        Next = "WaitForJobCompletion"
      }

      # Step 3: Wait for Bronze→Silver job completion
      WaitForJobCompletion = {
        Type = "Wait"
        Seconds = 180  # 3 minutes
        Next = "StartCrawlerBackground"
      }

      # Step 4: Start Silver Crawler in Background (Non-Blocking)
      StartCrawlerBackground = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = var.silver_crawler_name
        }
        ResultPath = "$.CrawlerResult"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "LogCrawlerError"
          }
        ]
        Next = "StartSilverToGoldJob"
      }

      # Step 5: Log Crawler Error (Non-Blocking)
      LogCrawlerError = {
        Type = "Pass"
        Parameters = {
          message = "Crawler start failed but continuing pipeline execution",
          crawler_error = "$$.Error",
          crawler_error_cause = "$$.Cause",
          timestamp = "$$.State.EnteredTime",
          correlation_id = "$.correlation_id"
        }
        ResultPath = "$.CrawlerError"
        Next = "StartSilverToGoldJob"
      }

      # Step 6: Start Silver to Gold Job
      StartSilverToGoldJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startJobRun"
        Parameters = {
          JobName = var.silver_to_gold_job_name
        }
        ResultPath = "$.SilverToGoldResult"
        Retry = [
          {
            ErrorEquals = ["States.TaskFailed"]
            IntervalSeconds = 60
            MaxAttempts = 3
            BackoffRate = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "SilverToGoldFailed"
          }
        ]
        Next = "PipelineSuccess"
      }

      # Success State
      PipelineSuccess = {
        Type = "Succeed"
        Comment = "Data pipeline completed successfully with background crawler processing"
      }

      # Error States
      BronzeToSilverFailed = {
        Type = "Fail"
        Error = "BronzeToSilverJobFailed"
        Cause = "Bronze to Silver job execution failed after retries"
      }

      SilverToGoldFailed = {
        Type = "Fail"
        Error = "SilverToGoldJobFailed"
        Cause = "Silver to Gold job execution failed after retries"
      }
    }
  })

  tags = {
    Name        = "${var.project}-data-pipeline"
    Environment = var.environment
    Project     = var.project
    Purpose     = "data-pipeline-orchestration"
  }
}

# Professional Step Functions Log Group
resource "aws_cloudwatch_log_group" "step_functions_log_group" {
  name              = "/aws/stepfunctions/assignment5-stepfunction"
  retention_in_days = 0 

  tags = {
    Name        = "assignment5-stepfunction-logs"
    Environment = var.environment
    Project     = var.project
    Purpose     = "step-functions-workflow-logs"
    ManagedBy   = "terraform"
  }
}


# CloudWatch Alarm for Step Functions Execution Duration
resource "aws_cloudwatch_metric_alarm" "step_functions_execution_duration" {
  alarm_name          = "${var.project}-step-functions-execution-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionTime"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Average"
  threshold           = 1800000  # 30 minutes (30 * 60 * 1000 ms)
  alarm_description   = "Alarm when Step Functions execution takes longer than 30 minutes"
  alarm_actions       = []  

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.data_pipeline.arn
  }

  tags = {
    Name        = "${var.project}-step-functions-duration-alarm"
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Alarm for Step Functions Execution Failures
resource "aws_cloudwatch_metric_alarm" "step_functions_execution_failure" {
  alarm_name          = "${var.project}-step-functions-execution-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when Step Functions execution fails"
  alarm_actions       = []  # Add SNS topic ARN here for notifications

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.data_pipeline.arn
  }

  tags = {
    Name        = "${var.project}-step-functions-failure-alarm"
    Environment = var.environment
    Project     = var.project
  }
}

# CloudWatch Alarm for Step Functions Execution Timeouts
 

# CloudWatch Alarm for Crawler Failures (Separate Monitoring)
resource "aws_cloudwatch_metric_alarm" "crawler_failure" {
  alarm_name          = "${var.project}-silver-crawler-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CrawlerSuccessRate"
  namespace           = "AWS/Glue"
  period              = 300
  statistic           = "Average"
  threshold           = 80  # Alert if success rate drops below 80%
  alarm_description   = "Alarm when Silver crawler success rate drops below 80%"
  alarm_actions       = []  # Add SNS topic ARN here for notifications

  dimensions = {
    CrawlerName = var.silver_crawler_name
  }

  tags = {
    Name        = "${var.project}-silver-crawler-failure-alarm"
    Environment = var.environment
    Project     = var.project
    Layer       = "medallion-silver-crawler"
  }
}

 


