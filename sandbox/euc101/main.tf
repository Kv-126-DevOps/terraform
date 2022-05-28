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
    EnvClass               = var.env_class
    Environment            = local.env_name
    Owner                  = "DevOps"
    Terraform              = "true"
    security_group_enabled = true
  }
}

########## Used modules #####
module "rabbitmq-security-group" {
  source              = "terraform-aws-modules/security-group/aws//modules/rabbitmq"
  version             = "~> 4.0"
  create              = var.rabbitmq_create[local.env_name]
  vpc_id              = var.vpc_id[local.env_name]
  name                = "${local.env_name}-${var.env_class}-rabbitmq-security-group"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  tags                = local.common_tags
}

resource "aws_mq_broker" "example" {
  broker_name = "rabbit-mq-${local.env_name}-${var.env_class}"
  # configuration {
  #   id       = aws_mq_configuration.test.id
  #   revision = aws_mq_configuration.test.latest_revision
  # }
  engine_type        = "RabbitMQ"
  engine_version     = "3.9.16"
  host_instance_type = "mq.t3.micro"
  security_groups    = [module.rabbitmq-security-group.security_group_id]
  user {
    username = var.mq_application_user
    password = var.mq_application_password
  }
}

module "ec2-instance-service" {
  source        = "terraform-aws-modules/ec2-instance/aws"
  version       = "~> 3.0"
  for_each      = toset(["json-filter", "rabbit-to-db", "rest-api", "frontend", "rabbit-to-slack"])
  name          = "${each.key}-${local.env_name}-${var.env_class}.${var.route_53_private_zone_name[local.env_name]}"
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
# module "aws-mq-service-instance" {
#   source                     = "cloudposse/mq-broker/aws"
#   namespace                  = "kv-126"
#   stage                      = "deploy"
#   name                       = "rabbit-mq-${local.env_name}-${var.env_class}"
#   apply_immediately          = true
#   auto_minor_version_upgrade = true
#   deployment_mode            = "SINGLE_INSTANCE"
#   engine_type                = "RabbitMQ"
#   engine_version             = "3.9.16"
#   host_instance_type         = "mq.t3.micro"
#   # publicly_accessible        = true
#   general_log_enabled        = true
#   audit_log_enabled          = false
#   encryption_enabled         = false
#   use_aws_owned_key          = false
#   mq_admin_user              = var.mq_admin_user
#   mq_admin_password          = var.mq_admin_password
#   mq_application_user        = var.mq_application_user
#   mq_application_password    = var.mq_application_password
#   vpc_id                     = "vpc-0d14e4956bccdc439"
#   subnet_ids                 = var.subnet_ids
#   # security_group_rules = [
#   #   {
#   #     type                     = "egress"
#   #     from_port                = 0
#   #     to_port                  = 65535
#   #     protocol                 = "-1"
#   #     cidr_blocks              = ["0.0.0.0/0"]
#   #     source_security_group_id = null
#   #     description              = "Allow all outbound trafic"
#   #   },
#   #   {
#   #     type                     = "ingress"
#   #     from_port                = 0
#   #     to_port                  = 65535
#   #     protocol                 = "tcp"
#   #     cidr_blocks              = []
#   #     source_security_group_id = null
#   #     description              = "Allow ingress traffic to AmazonMQ from trusted Security Groups"
#   #   }
#   # ]
# }



################ Route53 ############

# module "route53-public-instance-frontend" {
#   source    = "terraform-aws-modules/route53/aws//modules/records"
#   version   = "~> 2.0"
#   zone_name = "kv126.pp.ua"
#   records = [
#     {
#       name = "ui"
#       type = "A"
#       alias = {
#         name    = "MAIN-LB-1389830226.eu-central-1.elb.amazonaws.com"
#         zone_id = "Z0793915QPXVRLWO8FP3"
#       }
#     }
#   ]
#   #depends_on = [module.zones]
# }

# module "route53-private-instances" {
#   source       = "terraform-aws-modules/route53/aws//modules/records"
#   version      = "~> 2.0"
#   zone_name    = "private-kv126.pp.ua"
#   private_zone = true
#   records = [
#     {
#       name = "json-filter"
#       type = "A"
#       records = [
#         module.ec2-instance-service["json-filter"].private_ip
#       ]
#     },
#     {
#       name = "rabbit-to-db"
#       type = "A"
#       records = [
#         module.ec2-instance-service["rabbit-to-db"].private_ip
#       ]
#     },
#     {
#       name = "rest-api"
#       type = "A"
#       records = [
#         module.ec2-instance-service["rest-api"].private_ip
#       ]
#     },
#     {
#       name = "frontend"
#       type = "A"
#       records = [
#         module.ec2-instance-service["frontend"].private_ip
#       ]
#     },
#     {
#       name = "rabbit-to-slack"
#       type = "A"
#       records = [
#         module.ec2-instance-service["rabbit-to-slack"].private_ip
#       ]
#     }
#   ]
# }
