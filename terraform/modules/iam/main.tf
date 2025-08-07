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
          [for bucket in var.s3_bucket_names : "arn:aws:s3:::${bucket}"],
          [for bucket in var.s3_bucket_names : "arn:aws:s3:::${bucket}/*"]
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
  for_each                = aws_iam_user.users
  user                    = each.value.name
  password_length         = 16
  password_reset_required = true
}

resource "aws_iam_user_group_membership" "group_membership" {
  for_each = aws_iam_user.users
  user     = each.value.name
  groups   = [aws_iam_group.data_engineers.name]
}
