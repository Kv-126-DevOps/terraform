# IAM Role Policies
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${local.env_name}-${var.env_class}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags                     = local.common_tags
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
