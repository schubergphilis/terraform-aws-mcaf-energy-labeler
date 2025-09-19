output "ecs_cluster_arn" {
  value       = local.cluster_arn
  description = "value of the ecs cluster arn"
}

output "s3_bucket_arn" {
  value       = local.bucket_arn
  description = "value of the s3 bucket arn"
}

output "s3_bucket_name" {
  value       = local.bucket_name
  description = "value of the s3 bucket name"
}

output "task_role_arn" {
  value       = module.iam_role["task"].arn
  description = "value of the task role arn"
}
