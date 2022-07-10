# IAM Role Policies
resource "aws_iam_role" "ecsTaskExecutionRole" {
  count              = var.ecs_create[local.env_name] ? 1 : 0
  name               = "${local.env_name}-${var.env_class}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = var.ecs_create[local.env_name] ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  count      = var.ecs_create[local.env_name] ? 1 : 0
  role       = aws_iam_role.ecsTaskExecutionRole[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
