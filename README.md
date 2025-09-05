# terraform-aws-mcaf-energy-labeler

```markdown
## ⚠️ Caution: Resource Creation in the same Run

If you create the KMS Key, ECS Cluster, or S3 bucket in the same Terraform run or workspace as this module, you may encounter errors such as `cannot compute count value`. To avoid this, create these resources in a separate run or ensure they exist before applying this module.
```

Terraform module to create an ECS scheduled task that periodically generates an AWS energy label based on [awsenergylabelerlib](https://github.com/schubergphilis/awsenergylabelerlib).

This module should be run in the AWS account that collects your aggregated Security Hub findings. In a typical Control Tower deployment, this would be the Audit account.

In it's most minimal input, this module will create an S3 bucket to store the generated energy labels and a scheduled ECS task that will run every Sunday at 13:00 UTC.

```hcl
module "aws-energy-labeler" {
  source = "schubergphilis/mcaf-energy-labeler/aws"

  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    zone_name = "MYZONE"
  }
}
```

Or to target a single account:

```hcl
module "aws-energy-labeler" {
  source = "schubergphilis/mcaf-energy-labeler/aws"

  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    single_account_id = "123456789012"
  }
}
```

Should you prefer to use an existing bucket, you can specify the bucket name:

```hcl
module "aws-energy-labeler" {
  source = "schubergphilis/mcaf-energy-labeler/aws"

  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    zone_name = "MYZONE"
  }

  bucket_name   = "mybucket"
  bucket_prefix = "/myreport/"
}
```

If you want to create multiple reports, for example with different configurations, you should also set the name to avoid colliding resource names:

```hcl
module "aws-energy-labeler" {
  for_each = {
    "myzone"    = { allowed_account_ids = ["123456789012"] },
    "otherzone" = { allowed_account_ids = ["234567890123"] },
  }

  source = "schubergphilis/mcaf-energy-labeler/aws"

  name        = "aws-energy-labeler-${each.value}"
  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    allowed_account_ids = each.value.allowed_account_ids
    zone_name           = each.key
  }
}
```

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
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_config"></a> [config](#input\_config) | Map containing labeler configuration options | <pre>object({<br>    allowed_account_ids        = optional(list(string), [])<br>    denied_account_ids         = optional(list(string), [])<br>    frameworks                 = optional(list(string), [])<br>    log_level                  = optional(string)<br>    report_suppressed_findings = optional(bool, false)<br>    single_account_id          = optional(string)<br>    zone_name                  = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The ARN of the KMS key to use for encryption | `string` | n/a | yes |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | The name of the bucket to store the exported findings (will be created if not specified) | `string` | `null` | no |
| <a name="input_bucket_prefix"></a> [bucket\_prefix](#input\_bucket\_prefix) | The prefix to use for the bucket | `string` | `"/"` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of an existing ECS cluster, if left empty a new cluster will be created | `string` | `null` | no |
| <a name="input_iam_permissions_boundary"></a> [iam\_permissions\_boundary](#input\_iam\_permissions\_boundary) | The permissions boundary to attach to the IAM role | `string` | `null` | no |
| <a name="input_iam_role_path"></a> [iam\_role\_path](#input\_iam\_role\_path) | The path for the IAM role | `string` | `"/"` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | The URI of the container image to use | `string` | `"ghcr.io/schubergphilis/awsenergylabeler:main"` | no |
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
