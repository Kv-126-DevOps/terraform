############# Pull SSM parameters for ECS task definition #############
data "aws_ssm_parameter" "mq_endpoint" {
  depends_on = [aws_ssm_parameter.mq_endpoint]
  name       = "/${var.env_class}/${local.env_name}/mq_endpoint"
}

data "aws_ssm_parameter" "rds_endpoint" {
  depends_on = [aws_ssm_parameter.rds_endpoint]
  name       = "/${var.env_class}/${local.env_name}/rds_endpoint"
}

data "aws_ssm_parameter" "mq_pass" {
  depends_on = [aws_ssm_parameter.mq_pass]
  name       = "/${var.env_class}/${local.env_name}/mq_pass"
}

data "aws_ssm_parameter" "rds_pass" {
  depends_on = [aws_ssm_parameter.rds_pass]
  name       = "/${var.env_class}/${local.env_name}/rds_pass"
}

############# Create task definitions for ECS #############
resource "aws_ecs_task_definition" "json_filter" {
  family       = "json_filter"
  network_mode = "bridge"
  cpu          = 256
  memory       = 128
  container_definitions = templatefile(".terraform/modules/task_definitions/json_filter.json",
    { mq_endpoint = data.aws_ssm_parameter.mq_endpoint.arn,
      mq_pass     = data.aws_ssm_parameter.mq_pass.arn
    }
  )
  requires_compatibilities = [
    "EC2"
  ]
  execution_role_arn = null
  task_role_arn      = null
}
