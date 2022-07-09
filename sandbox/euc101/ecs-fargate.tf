########## Service Discovery ##########
### Create private dns namespace ###
resource "aws_service_discovery_private_dns_namespace" "segment" {
  name        = "${local.env_name}-${var.env_class}.local"
  description = "${var.env_class} service discovery"
  vpc         = var.vpc_id[local.env_name]
}

### Applications service discovery service ###
resource "aws_service_discovery_service" "applications" {
  for_each = toset(["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api", "frontend"])
  name     = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.segment.id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}


########## ECS Fargate Task Definitions ##########
### Application task definition ###
resource "aws_ecs_task_definition" "applications" {
  for_each = toset(["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api"])
  family   = "${each.key}_task"
  container_definitions = templatefile("./templates/task_definitions/${each.key}.json",
    { mq_endpoint  = split(":", split("//", module.amazon-mq-service.endpoint.0)[1])[0],
      mq_pass      = random_password.mq_pass[0].result,
      rds_endpoint = split(":", module.aws-rds.db_instance_endpoint)[0],
      rds_pass     = module.aws-rds.db_instance_password,
      slack_url    = var.slack_url,
      cloudwatch   = aws_cloudwatch_log_group.log-group.id,
      region       = var.region
    }
  )
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  tags                     = local.common_tags
}

data "aws_ecs_task_definition" "applications" {
  for_each        = toset(["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api"])
  task_definition = aws_ecs_task_definition.applications["${each.key}"].family
}

######## Get rest_api ECS service host ########
data "aws_route53_zone" "selected" {
  depends_on   = [aws_service_discovery_service.applications["rest_api"]]
  name         = aws_service_discovery_private_dns_namespace.segment.name
  private_zone = true
}

data "external" "restapi_service" {
  depends_on = [time_sleep.waiting_rest_api]
  program    = ["bash", "./templates/scripts/get_service.sh"]
  query = {
    hosted_zone = data.aws_route53_zone.selected.zone_id
    service     = "rest_api.${local.env_name}-${var.env_class}.local."
  }
}

### Awaiting for rest_api service ###
resource "time_sleep" "waiting_rest_api" {
  depends_on      = [aws_ecs_service.applications["rest_api"]]
  create_duration = "45s"
}

### frontend task definition ###
resource "aws_ecs_task_definition" "frontend" {
  family     = "frontend_task"
  depends_on = [aws_ecs_service.applications["rest_api"]]
  container_definitions = templatefile("./templates/task_definitions/frontend.json",
    { service_restapi = data.external.restapi_service.result.service_host,
      cloudwatch      = aws_cloudwatch_log_group.log-group.id,
      region          = var.region
    }
  )
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn

  tags = local.common_tags
}

data "aws_ecs_task_definition" "frontend" {
  task_definition = aws_ecs_task_definition.frontend.family
}


########## ECS Fargate Services ##########
### Applications service ###
resource "aws_ecs_service" "applications" {
  depends_on           = [module.amazon-mq-service, module.aws-rds]
  for_each             = toset(["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api"])
  name                 = "${each.key}_service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster.id
  task_definition      = "${aws_ecs_task_definition.applications["${each.key}"].family}:${max(aws_ecs_task_definition.applications["${each.key}"].revision, data.aws_ecs_task_definition.applications["${each.key}"].revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = false

  service_registries {
    registry_arn = aws_service_discovery_service.applications["${each.key}"].arn
  }

  network_configuration {
    subnets          = [var.subnet_id[local.env_name]]
    assign_public_ip = true
    security_groups  = ["sg-070712bd20c3ac748", "sg-00aebda5b39acaef6", module.security-group-json.security_group_id]
  }
}

### frontend service ###
resource "aws_ecs_service" "frontend" {
  depends_on           = [aws_ecs_service.applications["rest_api"]]
  name                 = "frontend_service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster.id
  task_definition      = "${aws_ecs_task_definition.frontend.family}:${max(aws_ecs_task_definition.frontend.revision, data.aws_ecs_task_definition.frontend.revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = false

  service_registries {
    registry_arn = aws_service_discovery_service.applications["frontend"].arn
  }

  network_configuration {
    subnets          = [var.subnet_id[local.env_name]]
    assign_public_ip = true
    security_groups  = var.security_group_ids
  }
}
