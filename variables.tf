variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = "The subnet ids where this lambda needs to run"
}

variable "security_group_egress_rules" {
  type = list(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    description                  = string
    from_port                    = optional(number, 0)
    ip_protocol                  = optional(string, "-1")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    to_port                      = optional(number, 0)
  }))
  default = [
    {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      description = "Allow outgoing HTTPS traffic for the labeler to work"
    }
  ]
  description = "Security Group egress rules"

  validation {
    condition     = alltrue([for o in var.security_group_egress_rules : (o.cidr_ipv4 != null || o.cidr_ipv6 != null || o.prefix_list_id != null || o.referenced_security_group_id != null)])
    error_message = "Although \"cidr_ipv4\", \"cidr_ipv6\", \"prefix_list_id\", and \"referenced_security_group_id\" are all marked as optional, you must provide one of them in order to configure the destination of the traffic."
  }
}

variable "security_group_name_prefix" {
  type        = string
  default     = null
  description = "An optional prefix to create a unique name of the security group. If not provided `var.name` will be used"
}

variable "cloudwatch_logs" {
  type        = bool
  default     = true
  description = "Whether or not to configure a CloudWatch log group"
}

variable "log_retention" {
  type        = number
  default     = 365
  description = "Number of days to retain log events in the specified log group"
}


variable "permissions_boundary" {
  type        = string
  default     = null
  description = "The permissions boundary to set on the role"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of tags to assign"
}

variable "timeout" {
  type        = number
  default     = 900
  description = "The timeout of the lambda"
}

variable "name" {
  type        = string
  description = "The name of the lambda"
  default     = "aws-energy-labeler"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "The ARN of the KMS key used to encrypt the cloudwatch log group and environment variables"
}

variable "memory_size" {
  type        = number
  default     = 512
  description = "The memory size of the lambda"
}

variable "environment" {
  type        = map(string)
  default     = { log_level = "DEBUG" }
  description = "The environment variables to set"
}

variable "description" {
  type        = string
  default     = "Lambda function for the AWS Energy Labeler"
  description = "A description of the lambda"
}

variable "architecture" {
  type        = string
  default     = "arm64"
  description = "Instruction set architecture of the Lambda function"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "Allowed values are \"arm64\" or \"x86_64\"."
  }
}

variable "labeler_config" {
  description = "A map containing all labeler configuration options"
  type = object({
    log-level                   = optional(string)
    region                      = optional(string)
    organizations-zone-name     = optional(string)
    audit-zone-name             = optional(string)
    single-account-id           = optional(string)
    frameworks                  = optional(list(string), [])
    allowed-account-ids         = optional(list(string), [])
    denied-account-ids          = optional(list(string), [])
    allowed-regions             = optional(list(string), [])
    denied-regions              = optional(list(string), [])
    export-path                 = optional(string)
    export-metrics-only         = optional(bool, false)
    to-json                     = optional(bool, false)
    report-closed-findings-days = optional(number)
    report-suppressed-findings  = optional(bool, false)
    account-thresholds          = optional(string)
    zone-thresholds             = optional(string)
    security-hub-query-filter   = optional(string)
    validate-metadata-file      = optional(string)
  })
  default = {}

  validation {
    condition     = length(compact([var.labeler_config.single-account-id, var.labeler_config.audit-zone-name, var.labeler_config.organizations-zone-name])) == 1
    error_message = "Parameters organizations-zone-name, audit-zone-name and single-account-id are mutually exclusive"
  }
  validation {
    condition     = var.labeler_config.export-path == null || (startswith(var.labeler_config.export-path, "s3://") && endswith(var.labeler_config.export-path, "/"))
    error_message = "The export-path parameter must start with 's3://' and end with a '/'."
  }
}

variable "labeler_cron_expression" {
  description = "The cron expression to be used for triggering the labeler"
  default     = "cron(0 13 ? * SUN *)"
  type        = string
}

variable "image_uri" {
  type        = string
  description = "The URI of the aws labeler lambda docker image"
  default     = "ghcr.io/schubergphilis/awsenergylabeler:main-lambda"
}
