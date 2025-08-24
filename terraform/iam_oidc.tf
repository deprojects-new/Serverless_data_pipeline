# OIDC for my AWS account


data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {

  github_owner = var.github_owner
  github_repo  = var.github_repo

  sub_any_branch     = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/*"
  sub_main           = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"
  sub_pull_request   = "repo:${var.github_owner}/${var.github_repo}:pull_request"
  sub_env_production = "repo:${local.github_owner}/${local.github_repo}:environment:production"



}


#role
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
        # local.sub_tags,  #  if needed
      ]
    }
  }
}




# Apply role: ONLY main branch OR a job using the GitHub Environment 'production'
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

# --- Terraform backend access (S3 state + DDB lock) ---
# Set these two variables in tfvars: tf_state_bucket, tf_lock_table; we use var.aws_region as well.
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
  name   = "tf-backend-access"
  policy = data.aws_iam_policy_document.tf_backend.json
}

# --- Plan role (read-only + backend) ---
resource "aws_iam_role" "gha_terraform_plan" {
  name               = "gha-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.assume_plan.json
  managed_policy_arns = [
    aws_iam_policy.tf_backend.arn,
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]
}

# --- Apply role (backend + deploy perms for your stack) ---
# NOTE: We restrict IAM writes/pass-role to roles prefixed "serverless-data-pipeline-"
data "aws_iam_policy_document" "tf_apply" {
  statement { # S3 control + data
    effect = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration", "s3:CreateBucket", "s3:PutBucket*", "s3:DeleteBucket", "s3:GetBucket*", "s3:ListBucket",
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucketMultipartUploads", "s3:AbortMultipartUpload",
      "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration"
    ]
    resources = ["*"]
  }
  statement { # Glue
    effect    = "Allow"
    actions   = ["glue:*Database*", "glue:*Table*", "glue:*Crawler*", "glue:*Job*", "glue:Get*", "glue:Create*", "glue:Update*", "glue:Delete*"]
    resources = ["*"]
  }
  statement { # Lambda
    effect    = "Allow"
    actions   = ["lambda:*Function*", "lambda:CreateFunction", "lambda:UpdateFunction*", "lambda:DeleteFunction", "lambda:Get*", "lambda:AddPermission", "lambda:RemovePermission"]
    resources = ["*"]
  }
  statement { # Step Functions
    effect    = "Allow"
    actions   = ["states:CreateStateMachine", "states:UpdateStateMachine", "states:DeleteStateMachine", "states:TagResource", "states:UntagResource", "states:List*", "states:Describe*"]
    resources = ["*"]
  }
  statement { # CloudWatch Logs/Alarms/Events
    effect = "Allow"
    actions = [
      "logs:*LogGroup*", "logs:*LogStream*", "logs:PutRetentionPolicy", "logs:PutSubscriptionFilter", "logs:DeleteSubscriptionFilter", "logs:CreateLogDelivery", "logs:DeleteLogDelivery", "logs:Describe*", "logs:List*", "logs:PutLogEvents",
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
      "events:PutRule", "events:DeleteRule", "events:PutTargets", "events:RemoveTargets", "events:DescribeRule", "events:List*"
    ]
    resources = ["*"]
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
  name   = "tf-apply-deploy"
  policy = data.aws_iam_policy_document.tf_apply.json
}

resource "aws_iam_role" "gha_terraform_apply" {
  name               = "gha-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.assume_apply.json
  managed_policy_arns = [
    aws_iam_policy.tf_backend.arn,
    aws_iam_policy.tf_apply.arn
  ]
}

# --- Outputs helpful for wiring the workflow ---
output "gha_plan_role_arn" { value = aws_iam_role.gha_terraform_plan.arn }
output "gha_apply_role_arn" { value = aws_iam_role.gha_terraform_apply.arn }