locals {
  // Validate bucket and ECS cluster resources exist if specified, otherwise create them
  bucket_name             = var.bucket_name != null ? var.bucket_name : module.s3[0].id
  bucket_name_with_prefix = format("%s%s", local.bucket_name, var.bucket_prefix)
  cluster_arn             = var.cluster_arn != null ? data.aws_ecs_cluster.selected[0].arn : aws_ecs_cluster.default[0].arn
  iam_name_prefix         = replace(title(var.name), "/[-_]/", "")

  // Sanitize the ECS task environment variables
  config = merge(
    var.config,
    {
      allowed_account_ids     = length(var.config.allowed_account_ids) > 0 ? join(", ", var.config.allowed_account_ids) : null
      denied_account_ids      = length(var.config.denied_account_ids) > 0 ? join(", ", var.config.denied_account_ids) : null
      disable_banner          = true
      disable_spinner         = true
      export_metrics_only     = true
      export_path             = "s3://${local.bucket_name_with_prefix}"
      frameworks              = length(var.config.frameworks) > 0 ? join(", ", var.config.frameworks) : null
      organizations_zone_name = var.config.zone_name
      region                  = data.aws_region.current.name
    }
  )

  // IAM roles to create
  roles = {
    "task" = {
      name          = "${local.iam_name_prefix}EcsTask"
      create_policy = true
      role_policy   = data.aws_iam_policy_document.ecs_task.json
    }
    "task_events" = {
      name        = "${local.iam_name_prefix}EcsEvents"
      policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"]
    }
    "task_execution" = {
      name        = "${local.iam_name_prefix}EcsTaskExecution"
      policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
    }
  }
}

data "aws_ecs_cluster" "selected" {
  count = var.cluster_arn != null ? 1 : 0

  cluster_name = var.cluster_arn
}

data "aws_subnet" "selected" {
  count = var.subnet_ids != null ? 1 : 0

  id = var.subnet_ids[0]
}

data "aws_region" "current" {}

resource "aws_security_group" "default" {
  # checkov:skip=CKV2_AWS_5: False positive finding, the security group is attached.

  count = var.subnet_ids != null ? 1 : 0

  name        = var.name
  description = "Security group for ECS cluster ${var.name}"
  vpc_id      = data.aws_subnet.selected[0].vpc_id
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "default" {
  for_each = var.subnet_ids != null ? { for v in var.security_group_egress_rules : v.description => v } : {}

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

  name = var.name
}

data "aws_iam_policy_document" "ecs_task" {
  # checkov:skip=CKV_AWS_356: Cannot set limit resources for security hub or org

  statement {
    sid       = "AllowReadOrg"
    resources = ["*"]

    actions = [
      "ec2:DescribeRegions",
      "iam:ListAccountAliases",
      "organizations:DescribeAccount",
      "organizations:DescribeOrganization",
      "organizations:ListAccounts",
    ]
  }

  statement {
    sid       = "AllowReadSecurityHub"
    resources = ["*"]

    actions = [
      "securityhub:GetFindings",
      "securityhub:ListEnabledProductsForImport",
      "securityhub:ListFindingAggregators",
    ]
  }

  statement {
    sid       = "AllowPutS3"
    actions   = ["s3:PutObject*"]
    resources = ["arn:aws:s3:::${local.bucket_name_with_prefix}*"]
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? { create = true } : {}

    content {
      sid       = "AllowUseKMS"
      resources = [var.kms_key_arn]

      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*",
      ]
    }
  }
}

module "iam_role" {
  for_each = local.roles

  source  = "schubergphilis/mcaf-role/aws"
  version = "~> 0.4.0"

  name                  = each.value.name
  create_policy         = try(each.value.create_policy, null)
  path                  = var.iam_role_path
  permissions_boundary  = var.iam_permissions_boundary
  policy_arns           = try(each.value.policy_arns, [])
  principal_identifiers = ["ecs-tasks.amazonaws.com"]
  principal_type        = "Service"
  role_policy           = try(each.value.role_policy, null)
  tags                  = var.tags
}

resource "aws_cloudwatch_event_rule" "default" {
  name                = var.name
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "default" {
  target_id = var.name
  arn       = local.cluster_arn
  rule      = aws_cloudwatch_event_rule.default.name
  role_arn  = module.iam_role["task_events"].arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.default.arn
    platform_version    = "1.4.0"

    dynamic "network_configuration" {
      for_each = var.subnet_ids != null ? { create : true } : {}

      content {
        assign_public_ip = false
        security_groups  = [aws_security_group.default[0].id]
        subnets          = var.subnet_ids
      }
    }
  }
}

module "aws_ecs_container_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/container-definition"
  version = "~> 5.11.4"

  name                            = var.name
  cloudwatch_log_group_name       = "/aws/ecs/${var.name}"
  create_cloudwatch_log_group     = true
  cloudwatch_log_group_kms_key_id = var.kms_key_arn
  essential                       = true
  image                           = var.image_uri
  readonly_root_filesystem        = true
  tags                            = var.tags

  environment = [
    for key, value in local.config : {
      name  = "AWS_LABELER_${upper(key)}",
      value = value != null ? try(join(", ", value), tostring(value)) : null
    }
    if value != null
  ]
}

resource "aws_ecs_task_definition" "default" {
  family                   = var.name
  container_definitions    = jsonencode([module.aws_ecs_container_definition.container_definition])
  cpu                      = 256
  execution_role_arn       = module.iam_role["task_execution"].arn
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = module.iam_role["task"].arn
  tags                     = var.tags
}

module "s3" {
  count = var.bucket_name == null ? 1 : 0

  source  = "schubergphilis/mcaf-s3/aws"
  version = "~> 0.14.1"

  name_prefix = "${lower(var.name)}-"
  kms_key_arn = var.kms_key_arn
  versioning  = true
  tags        = var.tags

  lifecycle_rule = [
    {
      id      = "basic-retention-rule"
      enabled = true

      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }

      expiration = {
        days = 90
      }

      transition = {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    }
  ]
}
