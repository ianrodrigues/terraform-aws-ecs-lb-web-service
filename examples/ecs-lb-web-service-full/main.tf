module "my_app" {
  source = "ianrodrigues/ecs-app/aws"

  name    = var.name
  environ = var.environ

  vpc_id            = var.vpc_id
  public_subnet_ids = var.public_subnet_ids

  tags = var.tags
}

module "nginx_backed_service" {
  source = "ianrodrigues/ecs-lb-web-service/aws"

  depends_on = [module.my_app]

  name    = "nginx"
  app     = var.name
  environ = var.environ

  cpu    = 256
  memory = 512

  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
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
