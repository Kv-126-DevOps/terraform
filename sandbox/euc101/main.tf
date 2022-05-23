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

module "rabbitmq_security_group" {
  source              = "terraform-aws-modules/security-group/aws//modules/rabbitmq"
  version             = "~> 4.0"
  create              = var.rabbitmq_create[local.env_name]
  vpc_id              = var.vpc_id[local.env_name]
  name                = "${local.env_name}-${var.env_class}-rabbitmq-security-group"
  ingress_cidr_blocks = ["0.0.0.0/0"]
  tags                = local.common_tags
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
  #vpc_id        = var.vpc_id[local.env_name]
  subnet_id = var.subnet_id[local.env_name]
  tags = merge(
    {
      group = "${each.key}"
    },
    local.common_tags
  )
}
