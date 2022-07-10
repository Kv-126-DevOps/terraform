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


variable "rds_cloudwatch_exports" {
  type        = list(string)
  description = "Cloudwatch logs exports for RDS"
  default     = ["postgresql", "upgrade"]
}

####################################################

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

variable "ecs_create" {
  type        = map(bool)
  description = "Whether to create ECS resources or not"
}

############ passwords ###########

variable "random_password_length" {
  description = "Length of random password to create"
  type        = number
  default     = 16
}

########## GitHub webhook events list ##########
variable "events" {
  type        = list(string)
  description = "A list of events which should trigger the webhook."
  default = [
    "check_run",
    "check_suite",
    "code_scanning_alert",
    "commit_comment",
    "create",
    "delete",
    "deploy_key",
    "deployment",
    "deployment_status",
    "fork",
    "gollum",
    "issue_comment",
    "issues",
    "label",
    "member",
    "meta",
    "milestone",
    "package",
    "page_build",
    "project",
    "project_card",
    "project_column",
    "public",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "push",
    "registry_package",
    "release",
    "repository",
    "repository_import",
    "repository_vulnerability_alert",
    "star",
    "status",
    "team_add",
    "watch"
  ]
}

variable "slack_url" {
  type        = string
  description = "Slack Url"
  default     = "https://hooks.slack.com/services/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"
}
