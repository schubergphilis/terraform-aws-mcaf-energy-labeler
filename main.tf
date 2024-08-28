locals {
  execution_type = var.subnet_ids == null ? "Basic" : "VPCAccess"
  vpc_config     = var.subnet_ids != null ? { create : true } : {}
  environment    = var.environment != null ? { create : true } : {}
  labeler_config_list_values = {
    frameworks          = join(",", var.labeler_config["frameworks"])
    allowed-account-ids = join(",", var.labeler_config["allowed-account-ids"])
    denied-account-ids  = join(",", var.labeler_config["denied-account-ids"])
    allowed-regions     = join(",", var.labeler_config["allowed-regions"])
    denied-regions      = join(",", var.labeler_config["denied-regions"])
  }
  labeler_config_merged = merge(var.labeler_config, local.labeler_config_list_values)
  labeler_config_list_values_non_null = {
    for k, v in local.labeler_config_merged : k => v if v != null && v != ""
  }
  labeler_config_processed = merge({ region = data.aws_region.current.name, disable-banner = true, disable-spinner = true }, local.labeler_config_list_values_non_null)
  s3_export_target         = try(strcontains(var.labeler_config["export-path"], "s3://"), false) ? { create : true } : {}
  single_account_id        = can(local.labeler_config_processed["single-account-id"]) ? { create : true } : {}
  not_single_account_id    = anytrue([can(local.labeler_config_processed["organizations-zone-name"]), can(local.labeler_config_processed["audit-zone-name"])]) ? { create : true } : {}
}

data "aws_region" "current" {}

resource "aws_iam_role" "role" {
  name = "${var.name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  permissions_boundary = try(var.permissions_boundary, null)
}


data "aws_iam_policy_document" "policy" {
  dynamic "statement" {
    for_each = local.s3_export_target

    content {
      effect  = "Allow"
      actions = ["s3:PutObject*"]
      resources = [
        "arn:aws:s3:::${trimprefix(var.labeler_config["export-path"], "s3://")}*",
        "arn:aws:s3:::${trimprefix(var.labeler_config["export-path"], "s3://")}"
      ]
    }
  }

  dynamic "statement" {
    for_each = local.single_account_id

    content {
      effect = "Allow"
      actions = [
        "iam:ListAccountAliases",
        "ec2:DescribeRegions",
        "securityhub:ListFindingAggregators",
        "securityhub:GetFindings",
        "securityhub:ListEnabledProductsForImport"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = local.not_single_account_id

    content {
      effect = "Allow"
      actions = [
        "organizations:DescribeOrganization",
        "organizations:ListAccounts",
        "organizations:DescribeAccount",
        "iam:ListAccountAliases",
        "ec2:DescribeRegions",
        "securityhub:ListFindingAggregators",
        "securityhub:GetFindings",
        "securityhub:ListEnabledProductsForImport"
      ]
      resources = ["*"]
    }
  }

}

resource "aws_iam_role_policy_attachment" "lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambda${local.execution_type}ExecutionRole"
  role       = aws_iam_role.role.name
}

resource "aws_iam_policy" "policy" {
  name   = "${var.name}-lambda-policy"
  policy = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "custom" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.role.name
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.default.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.default.arn
}

resource "aws_cloudwatch_log_group" "default" {
  count = var.cloudwatch_logs ? 1 : 0

  name              = "/aws/lambda/${var.name}"
  kms_key_id        = var.kms_key_arn
  retention_in_days = var.log_retention
  tags              = var.tags
}

data "aws_subnet" "selected" {
  count = var.subnet_ids != null ? 1 : 0

  id = var.subnet_ids[0]
}

resource "aws_security_group" "default" {
  #checkov:skip=CKV2_AWS_5: False positive finding, the security group is attached.
  count = var.subnet_ids != null ? 1 : 0

  name        = var.security_group_name_prefix == null ? var.name : null
  name_prefix = var.security_group_name_prefix != null ? var.security_group_name_prefix : null
  description = "Security group for lambda ${var.name}"
  vpc_id      = data.aws_subnet.selected[0].vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "default" {
  for_each = var.subnet_ids != null && length(var.security_group_egress_rules) != 0 ? { for v in var.security_group_egress_rules : v.description => v } : {}

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.default[0].id
  to_port                      = each.value.to_port
}

// tfsec:ignore:aws-lambda-enable-tracing
resource "aws_lambda_function" "default" {
  #checkov:skip=CKV_AWS_50: "AWS Lambda functions with tracing not enabled - We are not using X-Ray
  #checkov:skip=CKV_AWS_116: "AWS Lambda function is not configured for a DLQ - All logging is visible in CloudWatch
  #checkov:skip=CKV_AWS_272: "AWS Lambda function is not configured to validate code-signing - Code is developed internally and signed by the CI/CD pipeline
  reserved_concurrent_executions = 1
  architectures                  = [var.architecture]
  description                    = var.description
  function_name                  = var.name
  kms_key_arn                    = var.environment != null ? var.kms_key_arn : null
  image_uri                      = var.image_uri
  memory_size                    = var.memory_size
  role                           = aws_iam_role.role.arn
  tags                           = var.tags
  timeout                        = var.timeout
  package_type                   = "Image"

  dynamic "environment" {
    for_each = local.environment

    content {
      variables = var.environment
    }
  }

  dynamic "vpc_config" {
    for_each = local.vpc_config

    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.default[0].id]
    }
  }
}

resource "aws_cloudwatch_event_rule" "default" {
  name        = "${var.name}-event-rule"
  description = "Trigger lambda with ${var.labeler_cron_expression}"

  schedule_expression = var.labeler_cron_expression
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.default.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.default.arn

  input = jsonencode(local.labeler_config_processed)
}
