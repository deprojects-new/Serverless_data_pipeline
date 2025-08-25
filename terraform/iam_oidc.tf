# OIDC for GitHub Actions integration with AWS

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

locals {
  github_owner = var.github_owner
  github_repo  = var.github_repo

  sub_any_branch     = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/*"
  sub_main           = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"
  sub_pull_request   = "repo:${var.github_owner}/${var.github_repo}:pull_request"
  sub_env_production = "repo:${local.github_owner}/${local.github_repo}:environment:production"
}

# Plan role trust policy - allows any branch/PR
data "aws_iam_policy_document" "assume_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        local.sub_any_branch,
        local.sub_pull_request,
      ]
    }
  }
}

# Apply role trust policy - only main branch or production environment
data "aws_iam_policy_document" "assume_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.sub_main, local.sub_env_production]
    }
  }
}

# Terraform backend access policy (S3 state + DynamoDB lock)
data "aws_iam_policy_document" "tf_backend" {
  statement {
    sid     = "S3StateAccess"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*"
    ]
  }
  
  statement {
    sid     = "DDBLock"
    effect  = "Allow"
    actions = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem", "dynamodb:UpdateItem", "dynamodb:DescribeTable"]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.tf_lock_table}"
    ]
  }
}

resource "aws_iam_policy" "tf_backend" {
  count  = var.enable_ci_bootstrap ? 1 : 0
  name   = "tf-backend-access"
  policy = data.aws_iam_policy_document.tf_backend.json
  
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Plan role (read-only + backend access)
resource "aws_iam_role" "gha_terraform_plan" {
  count              = var.enable_ci_bootstrap ? 1 : 0
  name               = "gha-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.assume_plan.json
  
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Apply role (full deployment permissions)
data "aws_iam_policy_document" "tf_apply" {
  statement { # S3 control + data (including object tagging)
    effect = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration", "s3:CreateBucket", "s3:PutBucket*", "s3:DeleteBucket", "s3:GetBucket*", "s3:ListBucket",
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucketMultipartUploads", "s3:AbortMultipartUpload",
      "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration",
      "s3:PutObjectTagging", "s3:GetObjectTagging", "s3:DeleteObjectTagging"
    ]
    resources = ["*"]
  }
  
  statement { # Glue (including tagging)
    effect    = "Allow"
    actions   = [
      "glue:*Database*", "glue:*Table*", "glue:*Crawler*", "glue:*Job*", 
      "glue:Get*", "glue:Create*", "glue:Update*", "glue:Delete*", 
      "glue:TagResource", "glue:UntagResource"
    ]
    resources = ["*"]
  }
  
  statement { # IAM management (including CI/CD infrastructure)
    effect = "Allow"
    actions = [
      "iam:TagOpenIDConnectProvider", "iam:TagPolicy", "iam:TagRole",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:GetPolicyVersion",
      "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:CreateRole", "iam:DeleteRole"
    ]
    resources = ["*"]
  }
  
  statement { # Lambda
    effect    = "Allow"
    actions   = [
      "lambda:*Function*", "lambda:CreateFunction", "lambda:UpdateFunction*", 
      "lambda:DeleteFunction", "lambda:Get*", "lambda:AddPermission", 
      "lambda:RemovePermission", "lambda:TagResource", "lambda:UntagResource"
    ]
    resources = ["*"]
  }
  
  statement { # Step Functions
    effect    = "Allow"
    actions   = [
      "states:CreateStateMachine", "states:UpdateStateMachine", "states:DeleteStateMachine", 
      "states:TagResource", "states:UntagResource", "states:List*", "states:Describe*"
    ]
    resources = ["*"]
  }
  
  statement { # CloudWatch Logs/Alarms/Events
    effect = "Allow"
    actions = [
      "logs:*LogGroup*", "logs:*LogStream*", "logs:PutRetentionPolicy", 
      "logs:PutSubscriptionFilter", "logs:DeleteSubscriptionFilter", 
      "logs:CreateLogDelivery", "logs:DeleteLogDelivery", "logs:Describe*", 
      "logs:List*", "logs:PutLogEvents",
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
      "events:PutRule", "events:DeleteRule", "events:PutTargets", 
      "events:RemoveTargets", "events:DescribeRule", "events:List*"
    ]
    resources = ["*"]
  }
  
  statement { # SNS for Glue alerts
    effect = "Allow"
    actions = [
      "sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", 
      "sns:SetTopicAttributes", "sns:Subscribe", "sns:Unsubscribe", 
      "sns:TagResource", "sns:UntagResource"
    ]
    resources = ["*"]
  }
  
  statement { # KMS for encryption
    effect = "Allow"
    actions = [
      "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["glue.amazonaws.com", "s3.amazonaws.com"]
    }
  }
  
  statement { # Create/attach on our own execution roles only (prefix-guarded)
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/serverless-data-pipeline-*"]
  }
  
  statement { # PassRole to services (prefix-guarded)
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/serverless-data-pipeline-*"]
  }
  
  statement { # Read-only IAM for lookups
    effect    = "Allow"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "tf_apply" {
  count  = var.enable_ci_bootstrap ? 1 : 0
  name   = "tf-apply-deploy"
  policy = data.aws_iam_policy_document.tf_apply.json
  
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Apply role with proper policy attachments
resource "aws_iam_role" "gha_terraform_apply" {
  count              = var.enable_ci_bootstrap ? 1 : 0
  name               = "gha-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.assume_apply.json
  
  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Policy attachments (replaces deprecated managed_policy_arns)
resource "aws_iam_role_policy_attachment" "plan_backend_policy" {
  count      = var.enable_ci_bootstrap ? 1 : 0
  role       = aws_iam_role.gha_terraform_plan[count.index].name
  policy_arn = aws_iam_policy.tf_backend[count.index].arn
}

resource "aws_iam_role_policy_attachment" "plan_readonly_policy" {
  count      = var.enable_ci_bootstrap ? 1 : 0
  role       = aws_iam_role.gha_terraform_plan[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "apply_backend_policy" {
  count      = var.enable_ci_bootstrap ? 1 : 0
  role       = aws_iam_role.gha_terraform_apply[count.index].name
  policy_arn = aws_iam_policy.tf_backend[count.index].arn
}

resource "aws_iam_role_policy_attachment" "apply_deploy_policy" {
  count      = var.enable_ci_bootstrap ? 1 : 0
  role       = aws_iam_role.gha_terraform_apply[count.index].name
  policy_arn = aws_iam_policy.tf_apply[count.index].arn
}

# Outputs for workflow integration
output "gha_plan_role_arn" { 
  value = try(aws_iam_role.gha_terraform_plan[0].arn, null) 
}

output "gha_apply_role_arn" { 
  value = try(aws_iam_role.gha_terraform_apply[0].arn, null) 
}
