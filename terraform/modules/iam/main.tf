resource "aws_iam_group" "data_engineers" {
  name = "DataEngineers"
}

resource "aws_iam_policy" "data_engineers_policy" {
  name        = "DataEngineersLeastPrivilegePolicy"
  description = "Grants least privilege access to required services"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl"
        ],
        Resource = [
          "arn:aws:s3:::${var.data_lake_bucket_name}",
          "arn:aws:s3:::${var.data_lake_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${var.data_lake_bucket_name}",
        Condition = {
          StringLike = {
            "s3:prefix" = ["bronze/*", "silver/*", "gold/*", "glue_scripts/*"]
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetCrawler",
          "glue:GetCrawlers",
          "glue:GetJob",
          "glue:GetJobs",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:StartCrawler",
          "glue:StartJobRun",
          "glue:StopCrawler",
          "glue:StopJobRun"
        ],
        Resource = [
          "arn:aws:glue:*:*:database/${var.project}-*",
          "arn:aws:glue:*:*:table/${var.project}-*/*",
          "arn:aws:glue:*:*:crawler/${var.project}-*",
          "arn:aws:glue:*:*:job/${var.project}-*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "lambda:GetFunction",
          "lambda:ListFunctions",
          "lambda:GetFunctionConfiguration",
          "lambda:ListEventSourceMappings"
        ],
        Resource = "arn:aws:lambda:*:*:function:${var.project}-*"
      },
      # CloudWatch Metrics - This is Read-only for monitoring
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ],
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project}-*",
          "arn:aws:logs:*:*:log-group:/aws/glue/jobs/${var.project}-*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ],
        Resource = [
          "arn:aws:athena:*:*:workgroup/${var.project}-*",
          "arn:aws:athena:*:*:datacatalog/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::${var.data_lake_bucket_name}/athena-results/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:GetUser",
          "iam:ListGroupsForUser"
        ],
        Resource = [
          "arn:aws:iam::*:role/${var.project}-*",
          "arn:aws:iam::*:user/${var.project}-*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.*.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "sts:GetCallerIdentity"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "attach_custom_policy" {
  group      = aws_iam_group.data_engineers.name
  policy_arn = aws_iam_policy.data_engineers_policy.arn
}

resource "aws_iam_user" "users" {
  for_each = toset(var.users)
  name     = each.value
  tags = {
    Department  = "Engineering"
    AccessLevel = "DataEngineer"
  }
}

resource "aws_iam_user_login_profile" "logins" {
  for_each                = toset(var.users)
  user                    = each.value
  password_length         = 16
  password_reset_required = true
}

resource "aws_iam_user_group_membership" "group_membership" {
  for_each = toset(var.users)
  user     = each.value
  groups   = [aws_iam_group.data_engineers.name]
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-lambda-execution-role"
    Environment = var.environment
    Project     = var.project
  }
}


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

# Glue Execution Role
resource "aws_iam_role" "glue_execution_role" {
  name = "${var.project}-glue-execution-role"

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
    Name        = "${var.project}-glue-execution-role"
    Environment = var.environment
    Project     = var.project
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
      }
    ]
  })
}

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