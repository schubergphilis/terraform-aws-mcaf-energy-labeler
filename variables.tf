variable "cluster_arn" {
  type        = string
  description = "The ARN of the ECS cluster"
  default     = null
}

variable "config" {
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
    condition     = length(compact([var.config.single-account-id, var.config.audit-zone-name, var.config.organizations-zone-name])) == 1
    error_message = "Parameters organizations-zone-name, audit-zone-name and single-account-id are mutually exclusive"
  }
  validation {
    condition     = var.config.export-path == null || can((startswith(var.config.export-path, "s3://")) && can(endswith(var.config.export-path, "/")))
    error_message = "The export-path parameter must start with 's3://' and end with a '/'."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encryption"
  default     = null
}

variable "memory" {
  type        = number
  default     = 512
  description = "The memory size of the task"
  validation {
    condition = contains([
      512,
      1024,
      2048
    ], var.memory)
    error_message = "Unsupported memory size."
  }
}

variable "repository" {
  type        = string
  description = "The ECR repository to pull the labeler image from"
  default     = "ghcr.io"
}

variable "schedule_expression" {
  description = "The cron expression to be used for triggering the labeler"
  default     = "cron(0 13 ? * SUN *)"
  type        = string
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

variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = "The subnet ids where this lambda needs to run"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of tags to assign"
}
