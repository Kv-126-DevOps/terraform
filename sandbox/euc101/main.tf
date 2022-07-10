########## AWS Provider ##########
provider "aws" {
  region = var.region
}

########## Configure S3 backend #########
terraform {
  backend "s3" {
    bucket         = "euc101-sandbox-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "tf_lock"
  }
}

########## Common composed values shared across the different modules ##########
locals {
  env_name = terraform.workspace
  common_tags = {
    EnvClass    = var.env_class
    Environment = local.env_name
    Owner       = "DevOps"
    Terraform   = "true"
  }
}

########## ECS Cluster ##########
resource "aws_ecs_cluster" "aws-ecs-cluster" {
  count = var.ecs_create[local.env_name] ? 1 : 0
  name  = "${local.env_name}-${var.env_class}-cluster"
  tags  = local.common_tags
}

########## ECS CloudWatch ##########
resource "aws_cloudwatch_log_group" "log-group" {
  count = var.ecs_create[local.env_name] ? 1 : 0
  name  = "/cluster-${local.env_name}-${var.env_class}/logs"
  tags  = local.common_tags
}


########## RabbitMQ ###########
module "amazon-mq-service" {
  source             = "github.com/Kv-126-DevOps/terraform-modules//rabbit-mq-module"
  create             = var.rabbitmq_create[local.env_name]
  broker_name        = "rabbit-${local.env_name}-${var.env_class}"
  engine_type        = "RabbitMQ"
  engine_version     = "3.9.16"
  host_instance_type = "mq.t3.micro"
  security_groups    = [module.rabbitmq-security-group.security_group_id]
  username           = data.aws_ssm_parameter.mq_user.value
  password           = random_password.mq_pass[0].result
}

########## RDS ##########
module "aws-rds" {
  source                              = "terraform-aws-modules/rds/aws"
  version                             = "~> 4.4.0"
  create_db_instance                  = var.rds_create[local.env_name]
  identifier                          = "postgres-${local.env_name}-${var.env_class}"
  create_db_option_group              = false
  create_db_parameter_group           = false
  iam_database_authentication_enabled = true
  engine                              = "postgres"
  engine_version                      = "14.1"
  family                              = "postgres14" # DB parameter group
  major_engine_version                = "14"         # DB option group
  instance_class                      = "db.t4g.micro"
  allocated_storage                   = 10
  db_name                             = "postgres"
  username                            = data.aws_ssm_parameter.rds_user.value
  port                                = 5432
  vpc_security_group_ids              = [module.security-group-rds.security_group_id]
  maintenance_window                  = "Mon:00:00-Mon:03:00"
  backup_window                       = "03:00-06:00"
  backup_retention_period             = 0
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  create_cloudwatch_log_group         = true
  tags                                = local.common_tags
}

########### EC2 instances for services ##########
module "ec2-instance-service" {
  source                 = "github.com/Kv-126-DevOps/terraform-modules//ec2-instance-module"
  create                 = var.ec2_instances_create[local.env_name]
  for_each               = toset(["rabbit_to_db", "rest_api", "frontend", "rabbit_to_slack"])
  name                   = "${each.key}_${local.env_name}_${var.env_class}.${var.route_53_private_zone_name[local.env_name]}"
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = "deploy"
  monitoring             = true
  vpc_security_group_ids = var.security_group_ids
  subnet_id              = var.subnet_id[local.env_name]
  tags = merge(
    {
      group = "${each.key}"
    },
    local.common_tags
  )
}

############ EC2 json-filter ############
module "ec2-instance-service-json" {
  source                 = "github.com/Kv-126-DevOps/terraform-modules//ec2-instance-module"
  create                 = var.ec2_instances_create[local.env_name]
  name                   = "json_filter_${local.env_name}_${var.env_class}.${var.route_53_private_zone_name[local.env_name]}"
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = "deploy"
  monitoring             = true
  vpc_security_group_ids = ["sg-070712bd20c3ac748", "sg-00aebda5b39acaef6", module.security-group-json.security_group_id]
  subnet_id              = var.subnet_id[local.env_name]
  tags = merge(
    {
      group = "json_filter"
    },
    local.common_tags
  )
}

############ Route53 / Target groups / Loadbalancers ############
module "alb_tg_attachment" {
  source           = "github.com/Kv-126-DevOps/terraform-modules//target-group-module"
  create           = var.ec2_instances_create[local.env_name]
  target_group_arn = var.target_group_arn
  target_id        = module.ec2-instance-service["frontend"].id
  port             = 5000
}
