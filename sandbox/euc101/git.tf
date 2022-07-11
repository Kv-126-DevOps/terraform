########## GitHub Provider ##########
provider "github" {
  token = data.aws_ssm_parameter.git_token.value
  owner = "Kv-126-DevOps"
}

########## Create GitHub WebHook For EC2 ##########
### Create GitHub WebHook ###
resource "github_repository_webhook" "ec2" {
  repository = "None"

  configuration {
    url          = "http://${module.ec2-instance-service-json.public_ip}:5000/"
    content_type = "json"
    insecure_ssl = false
  }
  active = true
  events = var.events
}


########## Create GitHub WebHook For ECS Fargate##########
### Awaiting for ECS services ###
resource "null_resource" "wait_for_json_filter_deploy" {
  depends_on      = [aws_ecs_service.applications["json_filter"]]
  count        = var.ecs_create[local.env_name] ? 1 : 0
  provisioner "local-exec" {
    command = "aws ecs wait services-stable --services ${aws_ecs_service.applications["json_filter"].name} --cluster ${aws_ecs_cluster.aws-ecs-cluster[0].name} --region ${var.region}"
  }
}

### get public ip ecs service ###
data "external" "json_ip" {
  depends_on = [null_resource.wait_for_json_filter_deploy]
  count      = var.ecs_create[local.env_name] ? 1 : 0
  program    = ["bash", "./templates/scripts/get_publicip.sh"]
  query = {
    cluster_name = aws_ecs_cluster.aws-ecs-cluster[0].name
    service      = aws_ecs_service.applications["json_filter"].name
  }
}

### Create WebHook##
resource "github_repository_webhook" "ecs" {
  count      = var.ecs_create[local.env_name] ? 1 : 0
  repository = "None"
  configuration {
    url          = "http://${data.external.json_ip[0].result.publicip}:5000/"
    content_type = "json"
    insecure_ssl = false
  }
  active = true
  events = var.events
}
