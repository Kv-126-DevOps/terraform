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

  events = [
    "check_run",
    "check_suite",
    "commit_comment",
    "create",
    "delete",
    "deployment",
    "deployment_status",
    "fork",
    "issue_comment",
    "issues",
    "label",
    "page_build",
    "project",
    "project_card",
    "project_column",
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "push",
    "release",
    "repository",
    "status"
  ]
}
