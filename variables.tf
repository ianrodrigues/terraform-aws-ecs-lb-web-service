variable "app" {
  type = string
}

variable "environ" {
  type = string
}

variable "workload" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "load_balancer_arn" {
  type = string
}

variable "load_balancer_rule_path" {
  type    = string
  default = "/"
}

variable "load_balancer_rule_priority" {
  type    = number
  default = 500
}

variable "cluster" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "logs_retention_in_days" {
  type    = number
  default = 14
}
