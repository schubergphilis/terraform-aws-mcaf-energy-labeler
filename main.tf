locals {
  name = "EnergyLabeler"

  cluster_arn = var.cluster_arn != null ? var.cluster_arn : resource.aws_ecs_cluster.default[0].arn

  ecs_events_iam_name         = "${local.name}EcsEvents"
  ecs_task_execution_iam_name = "${local.name}EcsTaskExecution"
  ecs_task_iam_name           = "${local.name}EcsTask"

  ecs_environment = [
    for name, value in {
      ACCOUNT_THRESHOLDS          = var.config.account-thresholds
      ALLOWED_ACCOUNT_IDS         = length(var.config.allowed-account-ids) > 0 ? join(", ", var.config.allowed-account-ids) : null
      ALLOWED_REGIONS             = length(var.config.allowed-regions) > 0 ? join(", ", var.config.allowed-regions) : null
      AUDIT_ZONE_NAME             = var.config.audit-zone-name
      DENIED_ACCOUNT_IDS          = length(var.config.denied-account-ids) > 0 ? join(", ", var.config.denied-account-ids) : null
      DENIED_REGIONS              = length(var.config.denied-regions) > 0 ? join(", ", var.config.denied-regions) : null
      DISABLE_BANNER              = true,
      DISABLE_SPINNER             = true
      EXPORT_METRICS_ONLY         = var.config.export-metrics-only
      EXPORT_PATH                 = var.config.export-path
      FRAMEWORKS                  = length(var.config.frameworks) > 0 ? join(", ", var.config.frameworks) : null
      LOG_LEVEL                   = var.config.log-level
      ORGANIZATIONS_ZONE_NAME     = var.config.organizations-zone-name
      REGION                      = var.config.region != null ? var.config.region : data.aws_region.current.name
      REPORT_CLOSED_FINDINGS_DAYS = var.config.report-closed-findings-days
      REPORT_SUPPRESSED_FINDINGS  = var.config.report-suppressed-findings
      SECURITY_HUB_QUERY_FILTER   = var.config.security-hub-query-filter
      SINGLE_ACCOUNT_ID           = var.config.single-account-id
      TO_JSON                     = var.config.to-json
      VALIDATE_METADATA_FILE      = var.config.validate-metadata-file
      ZONE_THRESHOLDS             = var.config.zone-thresholds
      } : {
      name  = "AWS_LABELER_${name}",
      value = value
    } if value != null
  ]

  s3_export_target    = try(strcontains(var.config["export-path"], "s3://"), false) ? { create : true } : {}
  single_account_id   = can(var.config["single-account-id"]) ? { create : true } : {}
  multiple_account_id = anytrue([can(var.config["organizations-zone-name"]), can(var.config["audit-zone-name"])]) ? { create : true } : {}
}

data "aws_subnet" "selected" {
  count = var.subnet_ids != null ? 1 : 0

  id = var.subnet_ids[0]
}

resource "aws_security_group" "default" {
  #checkov:skip=CKV2_AWS_5: False positive finding, the security group is attached.
  count = var.subnet_ids != null ? 1 : 0

  name        = local.name
  description = "Security group for ESC ${local.name}"
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

resource "aws_ecs_cluster" "default" {
  count = var.cluster_arn == null ? 1 : 0

  name = "ecs-scheduled-task"
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_task" {
  dynamic "statement" {
    for_each = local.s3_export_target

    content {
      effect  = "Allow"
      actions = ["s3:PutObject*"]
      resources = [
        "arn:aws:s3:::${trimprefix(var.config["export-path"], "s3://")}*",
        "arn:aws:s3:::${trimprefix(var.config["export-path"], "s3://")}"
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
    for_each = local.multiple_account_id

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

module "task_role" {
  source  = "schubergphilis/mcaf-role/aws"
  version = "~> 0.4.0"

  name                  = local.ecs_task_iam_name
  create_policy         = true
  permissions_boundary  = null
  principal_identifiers = ["ecs-tasks.amazonaws.com"]
  principal_type        = "Service"
  role_policy           = data.aws_iam_policy_document.ecs_task.json
  tags                  = merge({ "Name" = local.ecs_task_iam_name }, var.tags)
}

module "task_execution_role" {
  source  = "schubergphilis/mcaf-role/aws"
  version = "~> 0.4.0"

  name                  = local.ecs_task_execution_iam_name
  create_policy         = true
  permissions_boundary  = null
  principal_identifiers = ["ecs-tasks.amazonaws.com"]
  principal_type        = "Service"
  role_policy           = data.aws_iam_policy.ecs_task_execution.policy
  tags                  = merge({ "Name" = local.ecs_task_execution_iam_name }, var.tags)
}

module "task_events_role" {
  source  = "schubergphilis/mcaf-role/aws"
  version = "~> 0.4.0"

  name                  = local.ecs_events_iam_name
  create_policy         = true
  permissions_boundary  = null
  principal_identifiers = ["ecs-tasks.amazonaws.com"]
  principal_type        = "Service"
  role_policy           = data.aws_iam_policy.ecs_events.policy
  tags                  = merge({ "Name" = local.ecs_events_iam_name }, var.tags)
}

resource "aws_cloudwatch_event_rule" "default" {
  name                = local.name
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "default" {
  target_id = local.name
  arn       = local.cluster_arn
  rule      = aws_cloudwatch_event_rule.default.name
  role_arn  = module.task_events_role.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.default.arn
    platform_version    = "1.4.0"

    network_configuration {
      assign_public_ip = false
      security_groups  = [aws_security_group.default[0].id]
      subnets          = var.subnet_ids
    }
  }
}

module "aws_ecs_container_definition" {

  source  = "terraform-aws-modules/ecs/aws//modules/container-definition"
  version = "~> 5.11.4"

  cloudwatch_log_group_name       = "/aws/ecs/${local.name}"
  create_cloudwatch_log_group     = true
  cloudwatch_log_group_kms_key_id = var.kms_key_arn
  environment                     = local.ecs_environment
  essential                       = true
  image                           = "${var.repository}/schubergphilis/awsenergylabeler:main"
  name                            = local.name
  readonly_root_filesystem        = true
  tags                            = var.tags
}

resource "aws_ecs_task_definition" "default" {
  family                   = local.name
  container_definitions    = jsonencode([module.aws_ecs_container_definition.container_definition])
  cpu                      = 256
  execution_role_arn       = module.task_execution_role.arn
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  tags                     = merge({ "Name" = local.name }, var.tags)
  task_role_arn            = module.task_role.arn
}

data "aws_iam_policy" "ecs_events" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

data "aws_iam_policy" "ecs_task_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
