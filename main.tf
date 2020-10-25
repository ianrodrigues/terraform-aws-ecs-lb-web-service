locals {
  prefix = "${random_string.service.keepers.name}-${random_string.service.id}"

  tags = {
    "app:name"        = random_string.service.keepers.app
    "app:environment" = random_string.service.keepers.environ
    "app:service"     = random_string.service.keepers.name
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_lb_listener" "http" {
  load_balancer_arn = var.load_balancer_arn
  port              = 80
}

data "aws_iam_policy_document" "secrets" {
  statement {
    actions   = ["ssm:GetParameters"]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:ResourceTag/app:name"
      values   = [var.app]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:ResourceTag/app:environment"
      values   = [var.environ]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:ResourceTag/app:service"
      values   = [var.name]
    }
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:*"]

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:ResourceTag/app:name"
      values   = [var.app]
    }

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:ResourceTag/app:environment"
      values   = [var.environ]
    }

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:ResourceTag/app:service"
      values   = [var.name]
    }
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]
  }
}

data "aws_iam_policy_document" "deny_iam_except_tagged_roles" {
  statement {
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["*"]
  }

  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"]

    condition {
      test     = "StringEquals"
      variable = "iam:ResourceTag/app:name"
      values   = [var.app]
    }

    condition {
      test     = "StringEquals"
      variable = "iam:ResourceTag/app:environment"
      values   = [var.environ]
    }

    condition {
      test     = "StringEquals"
      variable = "iam:ResourceTag/app:service"
      values   = [var.name]
    }
  }
}

resource "random_string" "service" {
  length  = 8
  lower   = false
  special = false

  keepers = {
    app     = var.app
    environ = var.environ
    name    = var.name
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "${local.prefix}-SecretsPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.secrets.json
}

module "ecs_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 2.0"

  create_role = true

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  role_name         = "${local.prefix}-ExecutionRole"
  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.secrets.arn,
  ]

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_policy" "deny_iam_except_tagged_roles" {
  name   = "${local.prefix}-DenyIAMExceptTaggedRoles"
  path   = "/"
  policy = data.aws_iam_policy_document.deny_iam_except_tagged_roles.json
}

module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 2.0"

  create_role = true

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  role_name         = "${local.prefix}-TaskRole"
  role_requires_mfa = false

  custom_role_policy_arns = [aws_iam_policy.deny_iam_except_tagged_roles.arn]

  tags = merge(var.tags, local.tags)
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/${var.app}-${var.environ}/${random_string.service.keepers.name}-${random_string.service.id}"
  retention_in_days = var.logs_retention_in_days

  tags = merge(var.tags, local.tags)
}

resource "aws_lb_target_group" "this" {
  name = local.prefix

  vpc_id = var.vpc_id

  target_type = "ip"
  protocol    = "HTTP"
  port        = var.container_port

  health_check {
    enabled           = true
    interval          = 10
    path              = "/"
    protocol          = "HTTP"
    timeout           = 5
    healthy_threshold = 2
  }

  tags = merge(var.tags, local.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = var.load_balancer_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = var.load_balancer_rule_path == "/" ? ["/*"] : [var.load_balancer_rule_path, "${var.load_balancer_rule_path}/*"]
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family = local.prefix

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = module.ecs_execution_role.this_iam_role_arn
  task_role_arn      = module.ecs_task_role.this_iam_role_arn

  container_definitions = jsonencode([{
    name  = var.name
    image = var.container_image

    portMappings = [
      {
        containerPort = var.container_port
      },
    ]

    environment = concat([
      {
        name  = "ECS_APP_NAME"
        value = var.app
      },
      {
        name  = "ECS_ENVIRON_NAME"
        value = var.environ
      },
      {
        name  = "ECS_SERVICE_NAME"
        value = var.name
      },
    ], var.container_extra_environment)

    secrets = concat([], var.container_extra_secrets)

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-stream-prefix" = var.name
      }
    }
  }])

  tags = merge(var.tags, local.tags)
}

resource "aws_ecs_service" "this" {
  depends_on = [aws_lb_listener_rule.this]

  name = local.prefix

  cluster = var.cluster

  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  launch_type    = "FARGATE"
  propagate_tags = "SERVICE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 30

  load_balancer {
    container_name   = var.name
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.this.arn
  }

  network_configuration {
    assign_public_ip = length(var.public_subnet_ids) == 0 ? false : true
    subnets          = length(var.public_subnet_ids) == 0 ? var.private_subnet_ids : var.public_subnet_ids
    security_groups  = var.security_group_ids
  }

  tags = merge(var.tags, local.tags)

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_count]
  }
}
