############# Password Generation #############
########## Rassword Generation for RabbitMQ ##########
resource "random_password" "mq_pass" {
  count            = var.rabbitmq_create[local.env_name] ? 1 : 0
  length           = var.random_password_length
  special          = false
}

########## Rassword Generation for RDS ##########
resource "random_password" "rds_pass" {
  count            = var.rds_create[local.env_name] ? 1 : 0
  length           = var.random_password_length
  special          = false
}

############# Pull Parameters from Amazon SSM #############
########## GIT_TOKEN ##########
data "aws_ssm_parameter" "git_token" {
  name = "/${var.env_class}/${local.env_name}/git_token"
}

########## RabbitMQ User ##########
data "aws_ssm_parameter" "mq_user" {
  name = "/${var.env_class}/${local.env_name}/mq_user"
}

########## RDS User ##########
data "aws_ssm_parameter" "rds_user" {
  name = "/${var.env_class}/${local.env_name}/rds_user"
}

############# Save Parameters to Amazon SSM #############
########## Save RDS password ##########
resource "aws_ssm_parameter" "rds_pass" {
  name        = "/${var.env_class}/${local.env_name}/rds_pass"
  description = "Password for RDS (Amazon RDS)"
  type        = "SecureString"
  value       = module.aws-rds.db_instance_password
  overwrite   = true

  tags = {
    environment = "generated_by_terraform"
  }
}

########## Save RabbitMQ password ##########
resource "aws_ssm_parameter" "mq_pass" {
  name        = "/${var.env_class}/${local.env_name}/mq_pass"
  description = "Password for RabitMQ brocker (Amazon MQ service)"
  type        = "SecureString"
  value       = random_password.mq_pass[0].result
  overwrite   = true

  tags = {
    environment = "generated_by_terraform"
  }
}

########## Save RDS Endpoint ##########
resource "aws_ssm_parameter" "rds_endpoint" {
  name        = "/${var.env_class}/${local.env_name}/rds_endpoint"
  description = "RDS Endpoint"
  type        = "String"
  value       = split(":",module.aws-rds.db_instance_endpoint)[0]
  overwrite   = true

  tags = {
    environment = "generated_by_terraform"
  }
}

########## Save rest-api private_ip ##########
resource "aws_ssm_parameter" "rest_api_host" {
  name        = "/${var.env_class}/${local.env_name}/rest_api_host"
  description = "rest-api Host"
  type        = "String"
  value       = module.ec2-instance-service["rest_api"].private_ip
  overwrite   = true

  tags = {
    environment = "generated_by_terraform"
  }
}

########## Save Amazon MQ SSL Endpoint ##########
resource "aws_ssm_parameter" "mq_endpoint" {
  name        = "/${var.env_class}/${local.env_name}/mq_endpoint"
  description = "RabitMQ Endpoint (Amazon MQ service)"
  type        = "String"
//  value       = substr(aws_mq_broker.rabbit.instances.0.endpoints.0,8,(length("${aws_mq_broker.rabbit.instances.0.endpoints.0}") - 5))
  value       = split(":",split("//", aws_mq_broker.rabbit[0].instances.0.endpoints.0)[1])[0]
  overwrite   = true

  tags = {
    environment = "generated_by_terraform"
  }
}