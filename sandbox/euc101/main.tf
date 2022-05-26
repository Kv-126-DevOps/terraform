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
  subnet_id = var.subnet_id[local.env_name]

  allocated_storage = 10

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "postgres"
  username = "dbuser"
  port     = 5432

  #db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [var.subnet_id[local.env_name]]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 0

  tags = local.common_tags
}