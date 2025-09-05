data "aws_caller_identity" "current" {}

data "aws_ecs_cluster" "selected" {
  count = var.cluster_arn != null ? 1 : 0

  cluster_name = var.cluster_arn
}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_region" "current" {}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}
