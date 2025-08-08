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
        Action = ["s3:*"],
        Resource = [
          "arn:aws:s3:::${var.data_lake_bucket_name}",
          "arn:aws:s3:::${var.data_lake_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "glue:*",
          "lambda:*",
          "cloudwatch:*",
          "logs:*",
          "events:*",
          "states:*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "iam:ListRoles",
          "iam:ListPolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants"
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
  name = "assignment5-lambda-execution-role"

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
    Name        = "assignment5-lambda-execution-role"
    Environment = var.environment
    Project     = var.project
  }
}


# Lambda Execution Role Policy
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "assignment5-lambda-execution-policy"
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
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJob"
        ]
        Resource = "*"
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
  name = "assignment5-glue-execution-role"

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
    Name        = "assignment5-glue-execution-role"
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
  name = "assignment5-glue-execution-policy"
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
      }
    ]
  })
}