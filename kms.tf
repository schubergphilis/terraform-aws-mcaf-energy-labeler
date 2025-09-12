data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid       = "Base Permissions for root user"
    actions   = ["kms:*"]
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalType"
      values   = ["Account"]
    }

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }

  statement {
    sid       = "Read/List permissions for all IAM users"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Describe*",
      "kms:GetKeyPolicy",
      "kms:ListAliases",
      "kms:ListKeys"
    ]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }

  statement {
    sid       = "Administrative permissions"
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Decrypt",
      "kms:DeleteAlias",
      "kms:Enable*",
      "kms:Encrypt",
      "kms:Get*",
      "kms:List*",
      "kms:Put*",
      "kms:ReplicateKey",
      "kms:Revoke*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:Update*"
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_session_context.current.issuer_arn]
    }
  }

  statement {
    sid       = "Permissions for Cloudwatch log group"
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]

    actions = [
      "kms:Decrypt",
      "kms:Describe*",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = [
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${var.name}"
      ]
    }
  }

  statement {
    sid       = "Permissions for energy labeler ECS task role"
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]

    principals {
      type        = "AWS"
      identifiers = [module.iam_role["task"].arn]
    }
  }

  statement {
    sid       = "Permissions to Decrypt for specified IAM principals"
    effect    = "Allow"
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]

    actions = [
      "kms:Decrypt"
    ]

    principals {
      type        = "AWS"
      identifiers = var.kms_key_decrypt_iam_principals
    }
  }
}

module "kms_key" {
  count = var.kms_key_arn == null ? 1 : 0

  source  = "schubergphilis/mcaf-kms/aws"
  version = "~> 0.3.0"

  name        = var.name
  description = "KMS key used for encrypting all energy labeler resources"
}

resource "aws_kms_key_policy" "default" {
  count = var.kms_key_arn == null ? 1 : 0

  key_id = module.kms_key[0].id
  policy = data.aws_iam_policy_document.kms_key_policy.json
}
