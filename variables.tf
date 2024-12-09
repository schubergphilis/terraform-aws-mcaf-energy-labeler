variable "bucket_name" {
  type        = string
  default     = null
  description = "The name of the bucket to store the exported findings (will be created if not specified)"

  validation {
    condition     = !can(regex(".*\\/$", var.bucket_name))
    error_message = "Bucket must not end with /"
  }
}

variable "bucket_prefix" {
  type        = string
  default     = "/"
  description = "The prefix to use for the bucket"
  nullable    = false

  validation {
    condition     = can(regex("^\\/", var.bucket_prefix))
    error_message = "Prefix must start with /"
  }

  validation {
    condition     = can(regex(".*\\/$", var.bucket_prefix))
    error_message = "Prefix must end with /"
  }
}

variable "cluster_arn" {
  type        = string
  default     = null
  description = "ARN of an existing ECS cluster, if left empty a new cluster will be created"
}

variable "config" {
  type = object({
    allowed_account_ids        = optional(list(string), [])
    denied_account_ids         = optional(list(string), [])
    frameworks                 = optional(list(string), [])
    log_level                  = optional(string)
    report_suppressed_findings = optional(bool, false)
    single_account_id          = optional(string)
    zone_name                  = optional(string)
  })
  description = "Map containing labeler configuration options"

  validation {
    condition     = var.config.zone_name != "" || var.config.single_account_id != ""
    error_message = "Either zone_name or single_account_id is required"
  }
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encryption"
}

variable "iam_role_path" {
  type        = string
  default     = "/"
  description = "The path for the IAM role"
}

variable "iam_permissions_boundary" {
  type        = string
  default     = null
  description = "The permissions boundary to attach to the IAM role"
}

variable "image_uri" {
  type        = string
  default     = "ghcr.io/schubergphilis/awsenergylabeler:main"
  description = "The URI of the container image to use"
}

variable "memory" {
  type        = number
  default     = 512
  description = "The memory size of the task"

  validation {
    condition     = contains([512, 1024, 2048], var.memory)
    error_message = "Unsupported memory size"
  }
}

variable "name" {
  type        = string
  description = "Name prefix of labeler resources"
  default     = "aws-energy-labeler"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.name))
    error_message = "Name must be alphanumeric and can contain - and _"
  }
}

variable "schedule_expression" {
  type        = string
  default     = "cron(0 13 ? * SUN *)"
  description = "The cron expression to be used for triggering the labeler"
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
    condition     = length(var.security_group_egress_rules) > 0
    error_message = "At least one egress rule must be provided"
  }

  validation {
    condition     = alltrue([for o in var.security_group_egress_rules : (o.cidr_ipv4 != null || o.cidr_ipv6 != null || o.prefix_list_id != null || o.referenced_security_group_id != null)])
    error_message = "One of \"cidr_ipv4\", \"cidr_ipv6\", \"prefix_list_id\", or \"referenced_security_group_id\" are required"
  }
}

variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = "VPC subnet ids this lambda runs from"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of tags to assign"
}
