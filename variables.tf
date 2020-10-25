variable "app" {
  type        = string
  description = "Name of the application."

  validation {
    condition     = can(regex("^[a-z\\-]+[a-z]$", var.app))
    error_message = "\"app\" can only contains lower case letter and hyphens."
  }
}

variable "environ" {
  type        = string
  description = "Environment of the application. It will be used to name the resources of this module."

  validation {
    condition     = can(regex("^[a-z\\-]+[a-z]$", var.environ))
    error_message = "\"environ\" can only contains lower case letter and hyphens."
  }
}

variable "name" {
  type        = string
  description = "Name of the service. It will be used to name the resources of this module."

  validation {
    condition     = can(regex("^[a-z\\-]+[a-z]$", var.name))
    error_message = "\"name\" can only contains lower case letter and hyphens."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "(Optional) Key-value map of resource tags."
}

variable "cpu" {
  type        = number
  default     = 256
  description = "(Optional) The number of cpu units used by the task."
}

variable "memory" {
  type        = number
  default     = 512
  description = "(Optional) The amount (in MiB) of memory used by the task."
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID."
}

variable "private_subnet_ids" {
  type        = list(string)
  default     = []
  description = "(Optional) A list of Private Subnet IDs. It is required to defined either \"private_subnet_ids\" or \"public_subnet_ids\"."
}

variable "public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "(Optional) A list of Public Subnet IDs. It is required to defined either \"private_subnet_ids\" or \"public_subnet_ids\"."
}

variable "security_group_ids" {
  type        = list(string)
  description = "A list of security groups associated with the task or service."
}

variable "load_balancer_arn" {
  type        = string
  description = "The ARN of the load balancer associated with service."
}

variable "load_balancer_rule_path" {
  type        = string
  default     = "/"
  description = "(Optional) A path to match against the request URL."
}

variable "load_balancer_rule_priority" {
  type        = number
  default     = null
  description = "(Optional) The priority for the rule between 1 and 50000. Leaving it unset will automatically set the rule with next available priority after currently existing highest rule. A listener can't have multiple rules with the same priority."
}

variable "cluster" {
  type        = string
  description = "ARN of an ECS cluster."
}

variable "desired_count" {
  type        = number
  default     = 2
  description = "(Optional) The number of instances of the task definition to place and keep running."
}

variable "container_image" {
  type        = string
  description = "The image used to start a container."
}

variable "container_port" {
  type        = number
  description = "The port number on the container that is bound to the user-specified or automatically assigned host port."
}

variable "container_extra_environment" {
  type = list(object({
    name  = string
    value = string
  }))

  default = []

  description = "Extra environment variables to pass to a container."
}

variable "container_extra_secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))

  default = []

  description = "Extra secrets to pass to the container."
}

variable "logs_retention_in_days" {
  type        = number
  default     = 14
  description = "(Optional) Specifies the number of days you want to retain log events in the specified log group."
}
