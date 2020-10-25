# ECS Load Balanced Web Service

### Injected Environment Variables

The module injects three environment variables into the tasks:

* `ECS_APP_NAME` - Contains the name of the application as set on the `app` property.
* `ECS_ENVIRON_NAME` - Contains the name of the environment as set on the `environ` property.
* `ECS_SERVICE_NAME` - Contains the name of the environment as set on the `name` property.

## Usage

```tf
module "my_app" {
  source = "ianrodrigues/ecs-app/aws"

  name    = "my-app"
  environ = "beta"

  vpc_id            = "vpc-093bee94"
  public_subnet_ids = ["subnet-002b5423", "subnet-0e0dbd33"]

  tags = {
    "terraform" = "true"
  }
}

module "nginx_backed_service" {
  source = "ianrodrigues/ecs-lb-web-service/aws"

  depends_on = [module.my_app]

  name    = "nginx"
  app     = "my-app"
  environ = "beta"

  cpu    = 256
  memory = 512

  vpc_id             = "vpc-093bee94"
  public_subnet_ids  = ["subnet-002b5423", "subnet-0e0dbd33"]
  security_group_ids = [module.my_app.this_app_security_group_id]

  load_balancer_arn           = module.my_app.this_lb_arn
  load_balancer_rule_path     = "/"
  load_balancer_rule_priority = 500

  cluster       = module.my_app.this_cluster
  desired_count = 2

  container_image = "nginx:alpine"
  container_port  = 80

  logs_retention_in_days = 14

  tags = {
    "terraform" = "true"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 0.13 |
| aws | ~> 2.54 |
| random | ~> 2.3 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 2.54 |
| random | ~> 2.3 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app | Name of the application. | `string` | n/a | yes |
| cluster | ARN of an ECS cluster. | `string` | n/a | yes |
| container\_extra\_environment | Extra environment variables to pass to a container. | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| container\_extra\_secrets | Extra secrets to pass to the container. | <pre>list(object({<br>    name      = string<br>    valueFrom = string<br>  }))</pre> | `[]` | no |
| container\_image | The image used to start a container. | `string` | n/a | yes |
| container\_port | The port number on the container that is bound to the user-specified or automatically assigned host port. | `number` | n/a | yes |
| cpu | (Optional) The number of cpu units used by the task. | `number` | `256` | no |
| desired\_count | (Optional) The number of instances of the task definition to place and keep running. | `number` | `2` | no |
| environ | Environment of the application. It will be used to name the resources of this module. | `string` | n/a | yes |
| load\_balancer\_arn | The ARN of the load balancer associated with service. | `string` | n/a | yes |
| load\_balancer\_rule\_path | (Optional) A path to match against the request URL. | `string` | `"/"` | no |
| load\_balancer\_rule\_priority | (Optional) The priority for the rule between 1 and 50000. Leaving it unset will automatically set the rule with next available priority after currently existing highest rule. A listener can't have multiple rules with the same priority. | `number` | `null` | no |
| load\_balancer\_stickiness\_duration | (Optional) The time period, in seconds, during which requests from a client should be routed to the same target. | `number` | `86400` | no |
| load\_balancer\_stickiness\_enabled | (Optional) Whether to enabled target group cookie stickiness. | `bool` | `true` | no |
| logs\_retention\_in\_days | (Optional) Specifies the number of days you want to retain log events in the specified log group. | `number` | `14` | no |
| memory | (Optional) The amount (in MiB) of memory used by the task. | `number` | `512` | no |
| name | Name of the service. It will be used to name the resources of this module. | `string` | n/a | yes |
| private\_subnet\_ids | (Optional) A list of Private Subnet IDs. It is required to defined either "private\_subnet\_ids" or "public\_subnet\_ids". | `list(string)` | `[]` | no |
| public\_subnet\_ids | (Optional) A list of Public Subnet IDs. It is required to defined either "private\_subnet\_ids" or "public\_subnet\_ids". | `list(string)` | `[]` | no |
| security\_group\_ids | A list of security groups associated with the task or service. | `list(string)` | n/a | yes |
| tags | (Optional) Key-value map of resource tags. | `map(string)` | `{}` | no |
| vpc\_id | The VPC ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| this\_tags | Key-value map of resource tags. |
