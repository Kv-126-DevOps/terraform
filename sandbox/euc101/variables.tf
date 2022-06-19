variable "region" {
  type        = string
  description = "The region where AWS operations will take place"
  default     = "eu-central-1"
}

variable "env_class" {
  type        = string
  description = "The environment class"
  default     = "sandbox"
}

#################################################
variable "vpc_id" {
  type        = map(string)
  description = "Envariroment VPC"
}

variable "subnet_id" {
  type        = map(string)
  description = "Default Subnet"
}

variable "ami" {
  type        = string
  description = "Default AMI"
  default     = "ami-09439f09c55136ecf"
}

variable "instance_type" {
  type        = string
  description = "Default instance type"
  default     = "t3a.nano"
}

variable "route_53_private_zone_name" {
  type        = map(string)
  description = "Envarioment Route 53 zone"
}

variable "subnet_ids" {
  type        = list(string)
  default     = ["subnet-0ad013438ee134ad6"]
  description = "Default Subnet"
}

variable "target_group_arn" {
  type        = string
  description = "ui target group"
  default     = "arn:aws:elasticloadbalancing:eu-central-1:779414916509:targetgroup/ui/16f43c5cda7c19d6"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group ids"
  default     = ["sg-070712bd20c3ac748", "sg-00aebda5b39acaef6"]
}

####################################################3
variable "rabbitmq_create" {
  type        = map(bool)
  description = "Whether to create rabbitmq resources or not"
}

variable "rds_create" {
  type        = map(bool)
  description = "Whether to create rds resources or not"
}

variable "ec2_instances_create" {
  type        = map(bool)
  description = "Whether to create EC2s resources or not"
}

variable "rds_create" {
  type        = bool
  default     = true
  description = "Whether to generate RDS Password or not"
}

variable "rabbitmq_create" {
  type        = bool
  default     = true
  description = "Whether to generate RabbitMQ Password or not"
}

############ users & passwords ###########

variable "random_password_length" {
  description = "Length of random password to create"
  type        = number
  default     = 16
}

/*
variable "dbuser" {
  type    = string
  default = "dbuser"
}

variable "dbpass" {
  type        = string
  description = "Password for user of DB"
}

variable "mquser" {
  type    = string
  default = "mquser"
}
variable "mqpass" {
  type        = string
  description = "Password for user of MQ"
}
*/