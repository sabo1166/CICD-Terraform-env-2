data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${var.project_name}-tfstate-${local.account_id}"
  repo_slug   = "${var.github_owner}/${var.github_repo}"
  oidc_url    = "token.actions.githubusercontent.com"
}

# ------------------------------------------------------------ state bucket
# Why: holds Terraform state for every environment. State can contain sensitive
# values and is the source of truth, so it is encrypted, versioned (recover from
# corruption/bad applies) and never public.

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true # losing this bucket orphans every environment
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3: no KMS key policy to manage or bill for
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced" # disables ACLs
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ----------------------------------------------------------------- OIDC
# Why: GitHub Actions proves its identity with a short-lived signed token, so
# no long-lived AWS keys are stored in GitHub.

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://${local.oidc_url}"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ------------------------------------------------------------- plan role
# Used by pull requests and the plan step on main. Read-only on infrastructure;
# it can only write the state *lock file*, never state itself.

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      values = [
        "repo:${local.repo_slug}:pull_request",
        "repo:${local.repo_slug}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "StateLockFileOnly"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*/terraform.tfstate.tflock"]
  }

  statement {
    sid       = "DescribeNetwork"
    actions   = ["ec2:Describe*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid       = "ReadLogsAndIam"
    actions   = ["logs:DescribeLogGroups", "logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = ["*"]
  }

  statement {
    sid = "ReadProjectRoles"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project_name}-*"]
  }
}

resource "aws_iam_role" "plan" {
  name                 = "${var.project_name}-github-plan"
  description          = "GitHub Actions: terraform plan (read-only) for ${local.repo_slug}"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "plan" {
  name   = "plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

# ------------------------------------------------------- per-env apply role
# One role per environment. Trust is pinned to the GitHub *Environment*, so the
# prod role can only be assumed by a job that passed prod's approval gate, and
# the dev role can never touch prod state or prod resources.

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["repo:${local.repo_slug}:environment:${each.key}"]
    }
  }
}

data "aws_iam_policy_document" "apply" {
  for_each = var.environments

  statement {
    sid       = "StateListOwnPrefix"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${each.key}/*"]
    }
  }

  statement {
    sid       = "StateObjectsOwnPrefix"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${each.key}/*"]
  }

  statement {
    sid = "ManageNetwork"
    actions = [
      "ec2:Describe*",
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
      "ec2:AllocateAddress", "ec2:ReleaseAddress",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
      "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:CreateVpcEndpoint", "ec2:DeleteVpcEndpoints", "ec2:ModifyVpcEndpoint",
      "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs",
      "ec2:CreateTags", "ec2:DeleteTags",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid = "ManageEnvLogGroup"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
      "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource", "logs:ListTagsLogGroup",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/${var.project_name}/${each.key}/*",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/${var.project_name}/${each.key}/*:*",
    ]
  }

  statement {
    sid = "FlowLogDelivery"
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogDelivery", "logs:DeleteLogDelivery",
      "logs:GetLogDelivery", "logs:ListLogDeliveries", "logs:UpdateLogDelivery",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageEnvRoles"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateAssumeRolePolicy",
      "iam:TagRole", "iam:UntagRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project_name}-${each.key}-*"]
  }

  statement {
    sid       = "PassFlowLogRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project_name}-${each.key}-vpc-flow-logs"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apply" {
  for_each = var.environments

  name                 = "${var.project_name}-github-apply-${each.key}"
  description          = "GitHub Actions: terraform apply for ${each.key} (${local.repo_slug}, environment ${each.key})"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  for_each = var.environments

  name   = "apply-${each.key}"
  role   = aws_iam_role.apply[each.key].id
  policy = data.aws_iam_policy_document.apply[each.key].json
}
