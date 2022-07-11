########## Service Discovery ##########
### Create private dns namespace ###
resource "aws_service_discovery_private_dns_namespace" "segment" {
  count       = var.ecs_create[local.env_name] ? 1 : 0
  name        = "${local.env_name}-${var.env_class}.local"
  description = "${var.env_class} service discovery"
  vpc         = var.vpc_id[local.env_name]
}

### Applications service discovery service ###
resource "aws_service_discovery_service" "applications" {
  for_each = toset([
    for app in ["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api", "frontend"] : app
    if var.ecs_create[local.env_name]
  ])
  name = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.segment[0].id
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
  for_each = toset([
    for app in ["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api"] : app
    if var.ecs_create[local.env_name]
  ])
  family = "${each.key}_task"
  container_definitions = templatefile("./templates/task_definitions/${each.key}.json",
    { mq_endpoint  = split(":", split("//", module.amazon-mq-service.endpoint.0)[1])[0],
      mq_pass      = random_password.mq_pass[0].result,
      rds_endpoint = split(":", module.aws-rds.db_instance_endpoint)[0],
      rds_pass     = module.aws-rds.db_instance_password,
      slack_url    = var.slack_url,
      cloudwatch   = aws_cloudwatch_log_group.log-group[0].id,
      region       = var.region
    }
  )
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole[0].arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole[0].arn
  tags                     = local.common_tags
}

data "aws_ecs_task_definition" "applications" {
  for_each = toset([
    for app in ["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api"] : app
    if var.ecs_create[local.env_name]
  ])
  task_definition = aws_ecs_task_definition.applications["${each.key}"].family
}


######## Get rest_api ECS service host ########
data "aws_route53_zone" "selected" {
  count        = var.ecs_create[local.env_name] ? 1 : 0
  name         = aws_service_discovery_private_dns_namespace.segment[0].name
  private_zone = true
}

### Awaiting for rest_api service ###
resource "null_resource" "wait_for_rest_api_deploy" {
  depends_on      = [aws_ecs_service.applications["rest_api"]]
  count        = var.ecs_create[local.env_name] ? 1 : 0
  provisioner "local-exec" {
    command = "aws ecs wait services-stable --services ${aws_ecs_service.applications["rest_api"].name} --cluster ${aws_ecs_cluster.aws-ecs-cluster[0].name} --region ${var.region}"
  }
}

### Get ip of restapi ecs service ###
data "external" "restapi_service" {
  depends_on = [null_resource.wait_for_rest_api_deploy]
  count      = var.ecs_create[local.env_name] ? 1 : 0
  program    = ["bash", "./templates/scripts/get_service.sh"]
  query = {
    hosted_zone = data.aws_route53_zone.selected[0].zone_id
    service     = "rest_api.${local.env_name}-${var.env_class}.local."
  }
}

### frontend task definition ###
resource "aws_ecs_task_definition" "frontend" {
  depends_on = [aws_ecs_service.applications["rest_api"]]
  count      = var.ecs_create[local.env_name] ? 1 : 0
  family     = "frontend_task"
  container_definitions = templatefile("./templates/task_definitions/frontend.json",
    { service_restapi = data.external.restapi_service[0].result.service_host,
      cloudwatch      = aws_cloudwatch_log_group.log-group[0].id,
      region          = var.region
    }
  )
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole[0].arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole[0].arn

  tags = local.common_tags
}

data "aws_ecs_task_definition" "frontend" {
  count           = var.ecs_create[local.env_name] ? 1 : 0
  task_definition = aws_ecs_task_definition.frontend[0].family
}


########## ECS Fargate Services ##########
### Applications service ###
resource "aws_ecs_service" "applications" {
  for_each = toset([
    for app in ["json_filter", "rabbit_to_db", /*"rabbit_to_slack",*/ "rest_api"] : app
    if var.ecs_create[local.env_name]
  ])
  name                 = "${each.key}_service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster[0].id
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
  count                = var.ecs_create[local.env_name] ? 1 : 0
  name                 = "frontend_service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster[0].id
  task_definition      = "${aws_ecs_task_definition.frontend[0].family}:${max(aws_ecs_task_definition.frontend[0].revision, data.aws_ecs_task_definition.frontend[0].revision)}"
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
