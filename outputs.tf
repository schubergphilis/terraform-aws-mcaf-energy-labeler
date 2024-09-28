output "task_role_arn" {
  value       = module.iam_role["task"].arn
  description = "value of the task role arn"
}
