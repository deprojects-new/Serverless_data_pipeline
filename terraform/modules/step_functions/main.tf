# Step Functions State Machine for Data Pipeline
resource "aws_sfn_state_machine" "data_pipeline" {
  name     = "${var.project}-data-pipeline"
  role_arn = var.step_functions_role_arn

  definition = jsonencode({
    Comment = "Serverless Data Pipeline Orchestration"
    StartAt = "SetExecutionContext"
    
    States = {
      # Step 1: Start Bronze to Silver Job
      # execution context for Glue jobs
      SetExecutionContext = {
        Type = "Pass"
        Parameters = {
          execution_name = "$$.Execution.Name"
          trigger_time = "$.trigger_time"
          bucket = "$.bucket"
          key = "$.key"
          size = "$.size"
          data_layer = "$.data_layer"
          environment = "$.environment"
        }
        Next = "StartBronzeToSilverJob"
      }

      StartBronzeToSilverJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startJobRun"
        Parameters = {
          JobName = var.bronze_to_silver_job_name
          Arguments = {
            "--execution-id" = "$.execution_name"
            "--pipeline-run" = "$.trigger_time"
            "--key" = "$.key"
          }
        }
        ResultPath = "$.BronzeToSilverResult"
        Retry = [
          {
            ErrorEquals = ["States.TaskFailed"]
            IntervalSeconds = 60
            MaxAttempts = 2
            BackoffRate = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "BronzeToSilverFailed"
          }
        ]
        Next = "InitializeRetryCount"
      }

      # retry count
      InitializeRetryCount = {
        Type = "Pass"
        Parameters = {
          RetryCount = 0
        }
        Next = "WaitForBronzeToSilver"
      }

      # Wait for Bronze to Silver Job to complete
      WaitForBronzeToSilver = {
        Type = "Wait"
        Seconds = 30  # Wait 30 seconds
        Next = "StartSilverCrawler"
      }

      # Step 2: Start Silver Crawler (after Bronze→Silver completes)
      StartSilverCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = var.silver_crawler_name
        }
        Retry = [
          {
            ErrorEquals = ["States.TaskFailed"]
            IntervalSeconds = 30
            MaxAttempts = 2
            BackoffRate = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "SilverCrawlerFailed"
          }
        ]
        Next = "WaitForSilverCrawler"
      }

      # Wait for Silver Crawler to complete
      WaitForSilverCrawler = {
        Type = "Wait"
        Seconds = 60  # Initial wait for crawler to start 
        Next = "CheckSilverCrawlerStatus"
      }

      # Check if Silver Crawler has completed
      CheckSilverCrawlerStatus = {
        Type = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:getCrawler"
        Parameters = {
          Name = var.silver_crawler_name
        }
        ResultPath = "$.CrawlerStatus"
        Next = "LogCrawlerStatus"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next = "SilverCrawlerFailed"
          }
        ]
      }

      # Log crawler status
      LogCrawlerStatus = {
        Type = "Pass"
        Parameters = {
          Message = "Checking crawler status",
          CrawlerState = "$.CrawlerStatus.Crawler.State",
          RetryCount = "$.RetryCount",
          Timestamp = "$$.State.EnteredTime"
        }
        ResultPath = "$.LogInfo"
        Next = "SilverCrawlerComplete?"
      }

      # Decision: Is crawler complete
      "SilverCrawlerComplete?" = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.CrawlerStatus.Crawler.State"
            StringEquals = "READY"
            Next = "StartSilverToGoldJob"
          },
          {
            Variable = "$.RetryCount"
            NumericGreaterThan = 5
            Next = "SilverCrawlerFailed"
          }
        ]
        Default = "WaitMoreForCrawler"
      }

      # Wait more if crawler is still running
      WaitMoreForCrawler = {
        Type = "Wait"
        Seconds = 120  # Wait 2 minutes before checking again
        Next = "IncrementRetryCount"
      }

      # Increment retry count
      IncrementRetryCount = {
        Type = "Pass"
        Parameters = {
          RetryCount = "States.MathAdd($.RetryCount, 1)"
        }
        Next = "CheckSilverCrawlerStatus"
      }

      # Step 3: Start Silver to Gold Job
      StartSilverToGoldJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startJobRun"
        Parameters = {
          JobName = var.silver_to_gold_job_name
        }
        Retry = [
          {
            ErrorEquals = ["States.TaskFailed"]
            IntervalSeconds = 60
            MaxAttempts = 2
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
        Comment = "Data pipeline completed successfully"
      }

      # Error States
      SilverCrawlerFailed = {
        Type = "Fail"
        Error = "SilverCrawlerExecutionFailed"
        Cause = "Silver crawler execution failed after retries"
      }

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
  threshold           = 3600000  
  alarm_description   = "This metric monitors Step Functions execution duration"
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
resource "aws_cloudwatch_metric_alarm" "step_functions_execution_timeout" {
  alarm_name          = "${var.project}-step-functions-execution-timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionTime"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Average"
  threshold           = 1800000  # 30 minutes (30 * 60 * 1000 ms)
  alarm_description   = "Alarm when Step Functions execution takes too long"
  alarm_actions       = []  # Add SNS topic ARN here for notifications

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.data_pipeline.arn
  }

  tags = {
    Name        = "${var.project}-step-functions-timeout-alarm"
    Environment = var.environment
    Project     = var.project
  }
}


