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

##########Security group for RDS##########
module "security-group-rds" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "RDS-sg"
  description = "Security group for PostgreSQL with opened ports  within VPC"
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
}
########## Used modules #####

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 4.3.0"
  identifier = "postgres-default"

  create_db_option_group    = false
  create_db_parameter_group = false

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "14.1"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.micro"

  allocated_storage = 10

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "postgres"
  username = "dbuser"
  port     =  5432
  password = "dbpass"

  db_subnet_group_name   = var.subnet_id[local.env_name]
  vpc_security_group_ids = [module.security-group-rds.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 0
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  tags = local.common_tags
}