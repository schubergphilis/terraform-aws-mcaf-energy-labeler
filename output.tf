output "lambda_arn" {
  value = module.energy_labeler_lambda.arn
}

output "lambda_function_name" {
  value = module.energy_labeler_lambda.name
}

output "lambda_role_arn" {
  value = module.energy_labeler_lambda.role_arn

}
