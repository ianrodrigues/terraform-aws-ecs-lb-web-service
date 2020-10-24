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
      variable = "ssm:ResourceTag/app:workload"
      values   = [var.workload]
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
      variable = "secretsmanager:ResourceTag/app:workload"
      values   = [var.workload]
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
      variable = "iam:ResourceTag/app:workload"
      values   = [var.workload]
    }
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "${var.app}-${var.environ}-${var.workload}-SecretsPolicy"
  path   = "/"
  policy = data.aws_iam_policy_document.secrets.json
}

module "ecs_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 2.0"

  create_role = true

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  role_name         = "${var.app}-${var.environ}-${var.workload}-ExecutionRole"
  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.secrets.arn,
  ]

  tags = merge(var.tags, {
    "app:name"        = var.app
    "app:environment" = var.environ
    "app:workload"    = var.workload
  })
}

resource "aws_iam_policy" "deny_iam_except_tagged_roles" {
  name   = "${var.app}-${var.environ}-${var.workload}-DenyIAMExceptTaggedRoles"
  path   = "/"
  policy = data.aws_iam_policy_document.deny_iam_except_tagged_roles.json
}

module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 2.0"

  create_role = true

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  role_name         = "${var.app}-${var.environ}-${var.workload}-TaskRole"
  role_requires_mfa = false

  custom_role_policy_arns = [aws_iam_policy.deny_iam_except_tagged_roles.arn]

  tags = merge(var.tags, {
    "app:name"        = var.app
    "app:environment" = var.environ
    "app:workload"    = var.workload
  })
}

resource "random_string" "service" {
  length  = 8
  lower   = false
  special = false

  keepers = {
    workload = var.workload
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name_prefix = "/aws/ecs/${var.app}/${var.environ}/${random_string.service.keepers.workload}-${random_string.service.id}"

  retention_in_days = var.logs_retention_in_days

  tags = merge(var.tags, {
    "app:name"        = var.app
    "app:environment" = var.environ
    "app:workload"    = var.workload
  })
}

resource "aws_lb_target_group" "this" {
  name = "${var.app}-${var.environ}-${var.workload}"

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

  tags = merge(var.tags, {
    "app:name"        = var.app
    "app:environment" = var.environ
    "app:workload"    = var.workload
  })

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
  family = "${var.app}-${var.environ}-${var.workload}"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = module.ecs_execution_role.this_iam_role_arn
  task_role_arn      = module.ecs_task_role.this_iam_role_arn

  container_definitions = jsonencode([{
    name  = var.workload
    image = var.container_image

    portMappings = [{
      containerPort = var.container_port
    }]

    environment = [
      {
        name  = "ECS_APP_NAME"
        value = var.app
      },
      {
        name  = "ECS_ENVIRON_NAME"
        value = var.environ
      },
      {
        name  = "ECS_WORKLOAD_NAME"
        value = var.workload
      },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-stream-prefix" = "${random_string.service.keepers.workload}-${random_string.service.id}"
      }
    }
  }])

  tags = merge(var.tags, {
    "app:name"        = var.app
    "app:environment" = var.environ
    "app:workload"    = var.workload
  })
}

resource "aws_ecs_service" "this" {
  depends_on = [aws_lb_listener_rule.this]

  name = "${random_string.service.keepers.workload}-${random_string.service.id}"

  cluster = var.cluster

  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  launch_type    = "FARGATE"
  propagate_tags = "SERVICE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 30

  load_balancer {
    container_name   = var.workload
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.this.arn
  }

  network_configuration {
    assign_public_ip = true # TODO
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
  }

  tags = merge(var.tags, {
    "app:name"        = var.app
    "app:environment" = var.environ
    "app:workload"    = var.workload
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_count]
  }
}
