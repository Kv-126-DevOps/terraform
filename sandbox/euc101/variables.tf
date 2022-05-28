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

variable "rabbitmq_create" {
  type        = map(bool)
  description = "Whether to create rabbitmq resources or not"
}

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
  default     = "t2.nano"
}

variable "route_53_private_zone_name" {
  type        = map(string)
  description = "Envarioment Route 53 zone"
}

variable "db_pass" {
  type = string
  description = "Password for user of DB"
}

variable "subnet_ids" {
  type        = list(string)
  default     = ["subnet-0ad013438ee134ad6"]
  description = "Default Subnet"
}

variable "mq_admin_user" {
  type = string
  default = "mqadmin"
}

variable "mq_admin_password" {
  type = string
  default = ""
}
variable "mq_application_user" {
  type = string
  default = "kv126"
}
variable "mq_application_password" {
  type = string
  default = ""
}

# variable "security_group_enabled" {
#   type        = bool
#   description = "Whether to create Security Group."
#   default     = true
# }

# variable "security_groups" {
#   type        = list(string)
#   default     = ["common"]
#   description = "security groups"
# }
