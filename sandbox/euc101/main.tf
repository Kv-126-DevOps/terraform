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

##########Security group for RabbitMQ##########
module "rabbitmq-security-group" {
  source              = "terraform-aws-modules/security-group/aws//modules/rabbitmq"
  version             = "~> 4.0"
  create              = var.rabbitmq_create[local.env_name]
  vpc_id              = var.vpc_id[local.env_name]
  name                = "${local.env_name}-${var.env_class}-rabbitmq-security-group"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  tags                = local.common_tags
}

##########Security group for RDS##########
module "security-group-rds" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "${local.env_name}-${var.env_class}-rds-security-group"
  description = "PostgreSQL with opened 5432 port within VPC"
  vpc_id      = var.vpc_id[local.env_name]

  # ingress
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

########## Creating Security group for RDS ##########
module "aws_rds" {
  source                    = "terraform-aws-modules/rds/aws"
  version                   = "~> 4.3.0"
  identifier                = "postgres-${local.env_name}-${var.env_class}"
  create_db_option_group    = false
  create_db_parameter_group = false

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "14.1"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.micro"
  allocated_storage    = 10

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "postgres"
  username = var.dbuser
  port     = 5432
  password = var.dbpass

  # db_subnet_group_name   = var.subnet_id[local.env_name]
  vpc_security_group_ids          = [module.security-group-rds.security_group_id]
  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  backup_retention_period         = 0
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true
  tags                            = local.common_tags
}

resource "aws_mq_broker" "rabbit" {
  broker_name        = "rabbit-${local.env_name}-${var.env_class}"
  engine_type        = "RabbitMQ"
  engine_version     = "3.9.16"
  host_instance_type = "mq.t3.micro"
  security_groups    = [module.rabbitmq-security-group.security_group_id]
  user {
    username = var.mquser
    password = var.mqpass
  }
}

module "ec2-instance-service" {
  source        = "terraform-aws-modules/ec2-instance/aws"
  version       = "~> 3.0"
  for_each      = toset(["json_filter", "rabbit_to_db", "rest_api", "frontend", "rabbit_to_slack"])
  name          = "${each.key}_${local.env_name}_${var.env_class}.${var.route_53_private_zone_name[local.env_name]}"
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = "deploy"
  monitoring    = true
  subnet_id     = var.subnet_id[local.env_name]
  tags = merge(
    {
      group = "${each.key}"
    },
    local.common_tags
  )
}

# resource "aws_route53_record" "frontend" {
#   zone_id = "Z0793915QPXVRLWO8FP3"
#   name    = "demo-ui"
#   type    = "A"
#   ttl     = "300"
#   records = [module.ec2-instance-service["frontend"].public_ip]
# }

# resource "aws_route53_record" "www" {
#   zone_id = "Z0793915QPXVRLWO8FP3"
#   name    = "kv126.pp.ua"
#   type    = "A"

#   alias {
#     name                   = aws_elb.main.dns_name
#     zone_id                = "Z0793915QPXVRLWO8FP3"
#     evaluate_target_health = true
#   }
# }

/*
module "aws-mq-service-instance" {
  source                     = "cloudposse/mq-broker/aws"
  namespace                  = "kv-126"
  stage                      = "deploy"
  name                       = "rabbit-mq-${local.env_name}-${var.env_class}"
  apply_immediately          = true
  auto_minor_version_upgrade = true
  deployment_mode            = "SINGLE_INSTANCE"
  engine_type                = "RabbitMQ"
  engine_version             = "3.9.16"
  host_instance_type         = "mq.t3.micro"
  # publicly_accessible        = true
  general_log_enabled        = true
  audit_log_enabled          = false
  encryption_enabled         = false
  use_aws_owned_key          = false
  mq_admin_user              = var.mq_admin_user
  mq_admin_password          = var.mq_admin_password
  mq_application_user        = var.mq_application_user
  mq_application_password    = var.mq_application_password
  vpc_id                     = "vpc-0d14e4956bccdc439"
  subnet_ids                 = var.subnet_ids
  # security_group_rules = [
  #   {
  #     type                     = "egress"
  #     from_port                = 0
  #     to_port                  = 65535
  #     protocol                 = "-1"
  #     cidr_blocks              = ["0.0.0.0/0"]
  #     source_security_group_id = null
  #     description              = "Allow all outbound trafic"
  #   },
  #   {
  #     type                     = "ingress"
  #     from_port                = 0
  #     to_port                  = 65535
  #     protocol                 = "tcp"
  #     cidr_blocks              = []
  #     source_security_group_id = null
  #     description              = "Allow ingress traffic to AmazonMQ from trusted Security Groups"
  #   }
  # ]
}
*/

/*
################ Route53 ############
module "route53-public-instance-frontend" {
  source    = "terraform-aws-modules/route53/aws//modules/records"
  version   = "~> 2.0"
  zone_name = "kv126.pp.ua"
  records = [
    {
      name = "demo-ui"
      type = "A"
      alias = {
        name    = "MAIN-LB-1389830226.eu-central-1.elb.amazonaws.com"
        zone_id = "Z0793915QPXVRLWO8FP3"
      }
    }
  ]
  #depends_on = [module.zones]
}
*/

/*
module "route53-private-instances" {
  source       = "terraform-aws-modules/route53/aws//modules/records"
  version      = "~> 2.0"
  zone_name    = "private-kv126.pp.ua"
  private_zone = true
  records = [
    {
      name = "json-filter"
      type = "A"
      records = [
        module.ec2-instance-service["json-filter"].private_ip
      ]
    },
    {
      name = "rabbit-to-db"
      type = "A"
      records = [
        module.ec2-instance-service["rabbit-to-db"].private_ip
      ]
    },
    {
      name = "rest-api"
      type = "A"
      records = [
        module.ec2-instance-service["rest-api"].private_ip
      ]
    },
    {
      name = "frontend"
      type = "A"
      records = [
        module.ec2-instance-service["frontend"].private_ip
      ]
    },
    {
      name = "rabbit-to-slack"
      type = "A"
      records = [
        module.ec2-instance-service["rabbit-to-slack"].private_ip
      ]
    }
  ]
}
*/
