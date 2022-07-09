########## Security Groups ##########
### Security group for RabbitMQ ###
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
    }
  ]
  tags = local.common_tags
}

### Security group for RDS  ###
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

### Secirity group for json-filter ###
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
