############## AWS Provider ############
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

############ Common composed values shared across the different modules ############
locals {
  env_name = terraform.workspace
  common_tags = {
    EnvClass    = var.env_class
    Environment = local.env_name
    Owner       = "DevOps"
    Terraform   = "true"
  }
}

########## Used modules #####

####### Security group for RabbitMQ #########
module "rabbitmq-security-group" {
  source              = "terraform-aws-modules/security-group/aws//modules/rabbitmq"
  version             = "~> 4.0"
  create              = var.rabbitmq_create[local.env_name]
  vpc_id              = var.vpc_id[local.env_name]
  name                = "${local.env_name}-${var.env_class}-rabbitmq-security-group"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_source_security_group_id = [
    {
      description              = "HTTPS for common sg"
      rule                     = "https-443-tcp"
      source_security_group_id = "sg-00aebda5b39acaef6"
    },
  ]
  tags = local.common_tags
}

########## RabbitMQ ###########
resource "aws_mq_broker" "rabbit" {
  count              = var.rabbitmq_create[local.env_name] ? 1 : 0
  broker_name        = "rabbit-${local.env_name}-${var.env_class}"
  engine_type        = "RabbitMQ"
  engine_version     = "3.9.16"
  host_instance_type = "mq.t3.micro"
  security_groups    = [module.rabbitmq-security-group.security_group_id]
  user {
    username = data.aws_ssm_parameter.mq_user.value
    password = random_password.mq_pass[0].result
  }
}


########## Security group for RDS / RDS ##########
module "security-group-rds" {
  source      = "terraform-aws-modules/security-group/aws"
  create      = var.rds_create[local.env_name]
  name        = "${local.env_name}-${var.env_class}-rds-security-group"
  description = "PostgreSQL with opened 5432 port within VPC"
  vpc_id      = var.vpc_id[local.env_name]
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access within VPC"
      cidr_blocks = "172.31.0.0/16"
    },
  ]
  tags = local.common_tags
}

############ RDS ##########
resource "aws_db_instance" "rds" {
  identifier             = "postgres-${local.env_name}-${var.env_class}"
  instance_class         = "db.t3.micro"
  allocated_storage      = 10
  engine                 = "postgres"
  engine_version         = "14.2"
  username               = data.aws_ssm_parameter.rds_user.value
  password               = random_password.rds_pass[0].result
  db_name                = "postgres"
  port                   = 5432
#  db_subnet_group_name   = ""
  vpc_security_group_ids = [module.security-group-rds.security_group_id]
  parameter_group_name   = aws_db_parameter_group.timezone.name
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags                            = local.common_tags
}

########### RDS parameter_group for config timezone ###########
resource "aws_db_parameter_group" "timezone" {
  name                     = "timezone"
  family                   = "postgres14"

  parameter {
      name  = "timezone"
      value = "Europe/Kiev"
    }

}

########### EC2 instances for services ##########
module "ec2-instance-service" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 3.0"
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

######### secirity group for json-filter ###########
module "security-group-json" {
  source      = "terraform-aws-modules/security-group/aws"
  create      = var.ec2_instances_create[local.env_name]
  name        = "${local.env_name}-${var.env_class}-json_filter-security-group"
  description = "Open 5000 port for webhooks"
  vpc_id      = var.vpc_id[local.env_name]
  ingress_with_cidr_blocks = [
    {
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      description = "Open 5000 port for webhook"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
  tags = local.common_tags
}

############### EC2 json-filter ############
module "ec2-instance-service-json" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 3.0"
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

######## Route53 / Target groups / Loadbalancers ###########
resource "aws_lb_target_group_attachment" "frontend" {
  count            = var.ec2_instances_create[local.env_name] ? 1 : 0
  target_group_arn = var.target_group_arn
  target_id        = module.ec2-instance-service["frontend"].id
  port             = 5000
}