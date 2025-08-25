
/*
# Lambda Execution Role Policy
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.project}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = "arn:aws:states:*:*:stateMachine:${var.project}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.data_lake_bucket_name}",
          "arn:aws:s3:::${var.data_lake_bucket_name}/*"
        ]
      }
    ]
  })
}
*/

# Glue Execution Role
resource "aws_iam_role" "glue_execution_role" {
  name = "${var.project}-${var.environment}-glue-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-glue-execution-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}


# Attach AWS managed policy for Glue
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Glue Execution Role Policy
resource "aws_iam_role_policy" "glue_execution_policy" {
  name = "${var.project}-glue-execution-policy"
  role = aws_iam_role.glue_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.data_lake_bucket_name}",
          "arn:aws:s3:::${var.data_lake_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:UpdateDatabase",
          "glue:DeleteDatabase",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:CreatePartition",
          "glue:DeletePartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:UpdatePartition",
          "glue:GetJobBookmark",
          "glue:PutJobBookmark",
          "glue:ResetJobBookmark"
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          "arn:aws:glue:*:*:database/*",
          "arn:aws:glue:*:*:table/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.*.amazonaws.com"
          }
        }
      }
    ]
  })
}

/*
# Step Functions Execution Role
resource "aws_iam_role" "step_functions_execution_role" {
  name = "${var.project}-step-functions-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-step-functions-execution-role"
    Environment = var.environment
    Project     = var.project
  }
}

# Step Functions Execution Role Policy
resource "aws_iam_role_policy" "step_functions_execution_policy" {
  name = "${var.project}-step-functions-execution-policy"
  role = aws_iam_role.step_functions_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJob"
        ]
        Resource = [
          "arn:aws:glue:*:*:crawler/${var.project}-*",
          "arn:aws:glue:*:*:job/${var.project}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:DescribeDestinations",
          "logs:PutDestination",
          "logs:PutDestinationPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}
*/