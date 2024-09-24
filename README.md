# terraform-aws-mcaf-energy-labeler

MCAF Terraform module to create a lambda function that periodically generates an AWS energy label based on [awsenergylabelerlib](https://github.com/schubergphilis/awsenergylabelerlib)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.64.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_iam_policy_document.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | The URI of the aws labeler lambda docker image. Needs to be an ECR image | `string` | n/a | yes |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Instruction set architecture of the Lambda function | `string` | `"arm64"` | no |
| <a name="input_cloudwatch_logs"></a> [cloudwatch\_logs](#input\_cloudwatch\_logs) | Whether or not to configure a CloudWatch log group | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | A description of the lambda | `string` | `"Lambda function for the AWS Energy Labeler"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment variables to set | `map(string)` | <pre>{<br>  "log_level": "DEBUG"<br>}</pre> | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The ARN of the KMS key used to encrypt the cloudwatch log group and environment variables | `string` | `null` | no |
| <a name="input_labeler_config"></a> [labeler\_config](#input\_labeler\_config) | A map containing all labeler configuration options | <pre>object({<br>    log-level                   = optional(string)<br>    region                      = optional(string)<br>    organizations-zone-name     = optional(string)<br>    audit-zone-name             = optional(string)<br>    single-account-id           = optional(string)<br>    frameworks                  = optional(list(string), [])<br>    allowed-account-ids         = optional(list(string), [])<br>    denied-account-ids          = optional(list(string), [])<br>    allowed-regions             = optional(list(string), [])<br>    denied-regions              = optional(list(string), [])<br>    export-path                 = optional(string)<br>    export-metrics-only         = optional(bool, false)<br>    to-json                     = optional(bool, false)<br>    report-closed-findings-days = optional(number)<br>    report-suppressed-findings  = optional(bool, false)<br>    account-thresholds          = optional(string)<br>    zone-thresholds             = optional(string)<br>    security-hub-query-filter   = optional(string)<br>    validate-metadata-file      = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_labeler_cron_expression"></a> [labeler\_cron\_expression](#input\_labeler\_cron\_expression) | The cron expression to be used for triggering the labeler | `string` | `"cron(0 13 ? * SUN *)"` | no |
| <a name="input_log_retention"></a> [log\_retention](#input\_log\_retention) | Number of days to retain log events in the specified log group | `number` | `365` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | The memory size of the lambda | `number` | `512` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the lambda | `string` | `"aws-energy-labeler"` | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | The permissions boundary to set on the role | `string` | `null` | no |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | Security Group egress rules | <pre>list(object({<br>    cidr_ipv4                    = optional(string)<br>    cidr_ipv6                    = optional(string)<br>    description                  = string<br>    from_port                    = optional(number, 0)<br>    ip_protocol                  = optional(string, "-1")<br>    prefix_list_id               = optional(string)<br>    referenced_security_group_id = optional(string)<br>    to_port                      = optional(number, 0)<br>  }))</pre> | <pre>[<br>  {<br>    "cidr_ipv4": "0.0.0.0/0",<br>    "description": "Allow outgoing HTTPS traffic for the labeler to work",<br>    "from_port": 443,<br>    "ip_protocol": "tcp",<br>    "to_port": 443<br>  }<br>]</pre> | no |
| <a name="input_security_group_name_prefix"></a> [security\_group\_name\_prefix](#input\_security\_group\_name\_prefix) | An optional prefix to create a unique name of the security group. If not provided `var.name` will be used | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The subnet ids where this lambda needs to run | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | The timeout of the lambda | `number` | `900` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_iam_role_arn"></a> [lambda\_iam\_role\_arn](#output\_lambda\_iam\_role\_arn) | n/a |
<!-- END_TF_DOCS -->

## License

**Copyright:** Schuberg Philis

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
