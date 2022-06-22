########## GitHub Provider ##########
provider "github" {
  token = data.aws_ssm_parameter.git_token.value
  owner = "Kv-126-DevOps"
}

########## Create GitHub WebHook ##########
resource "github_repository_webhook" "none" {
  repository = "None"

  configuration {
    url          = "http://${module.ec2-instance-service-json.public_ip}:5000/"
    content_type = "json"
    insecure_ssl = false
  }

  active = true

  events = var.events
}
