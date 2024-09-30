# terraform-aws-mcaf-energy-labeler

Terraform module to create an ECS scheduled task that periodically generates an AWS energy label based on [awsenergylabelerlib](https://github.com/schubergphilis/awsenergylabelerlib).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.20 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.20 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_ecs_container_definition"></a> [aws\_ecs\_container\_definition](#module\_aws\_ecs\_container\_definition) | terraform-aws-modules/ecs/aws//modules/container-definition | ~> 5.11.4 |
| <a name="module_iam_role"></a> [iam\_role](#module\_iam\_role) | schubergphilis/mcaf-role/aws | ~> 0.4.0 |
| <a name="module_s3"></a> [s3](#module\_s3) | schubergphilis/mcaf-s3/aws | ~> 0.14.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_ecs_cluster.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_task_definition.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_ecs_cluster.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The name of the bucket to store the exported findings (will be created if not specified) | `string` | `null` | no |
| <a name="input_bucket_prefix"></a> [bucket\_prefix](#input\_bucket\_prefix) | The prefix to use for the bucket | `string` | `"/"` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of an existing ECS cluster | `string` | `null` | no |
| <a name="input_config"></a> [config](#input\_config) | Map containing labeler configuration options | <pre>object({<br>    account_thresholds          = optional(string)<br>    allowed_account_ids         = optional(list(string), [])<br>    allowed_regions             = optional(list(string), [])<br>    audit_zone_name             = optional(string)<br>    denied_account_ids          = optional(list(string), [])<br>    denied_regions              = optional(list(string), [])<br>    export_metrics_only         = optional(bool, false)<br>    frameworks                  = optional(list(string), [])<br>    log_level                   = optional(string)<br>    organizations_zone_name     = optional(string)<br>    region                      = optional(string)<br>    report_closed_findings_days = optional(number)<br>    report_suppressed_findings  = optional(bool, false)<br>    security_hub_query_filter   = optional(string)<br>    single_account_id           = optional(string)<br>    to_json                     = optional(bool, false)<br>    validate_metadata_file      = optional(string)<br>    zone_thresholds             = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_iam_permissions_boundary"></a> [iam\_permissions\_boundary](#input\_iam\_permissions\_boundary) | The permissions boundary to attach to the IAM role | `string` | `null` | no |
| <a name="input_iam_role_path"></a> [iam\_role\_path](#input\_iam\_role\_path) | The path for the IAM role | `string` | `"/"` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | The URI of the container image to use | `string` | `"ghcr.io/schubergphilis/awsenergylabeler:main"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The ARN of the KMS key to use for encryption | `string` | `null` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | The memory size of the task | `number` | `512` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix of labeler resources | `string` | `"aws-energy-labeler"` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | The cron expression to be used for triggering the labeler | `string` | `"cron(0 13 ? * SUN *)"` | no |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | Security Group egress rules | <pre>list(object({<br>    cidr_ipv4                    = optional(string)<br>    cidr_ipv6                    = optional(string)<br>    description                  = string<br>    from_port                    = optional(number, 0)<br>    ip_protocol                  = optional(string, "-1")<br>    prefix_list_id               = optional(string)<br>    referenced_security_group_id = optional(string)<br>    to_port                      = optional(number, 0)<br>  }))</pre> | <pre>[<br>  {<br>    "cidr_ipv4": "0.0.0.0/0",<br>    "description": "Allow outgoing HTTPS traffic for the labeler to work",<br>    "from_port": 443,<br>    "ip_protocol": "tcp",<br>    "to_port": 443<br>  }<br>]</pre> | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | VPC subnet ids this lambda runs from | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | value of the task role arn |
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
