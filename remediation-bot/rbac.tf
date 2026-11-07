resource "aws_iam_role" "lambda_exec" {
  name = "aiops-remediation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_eks_access_entry" "lambda" {
  cluster_name = data.aws_eks_cluster.main.name
  principal_arn = aws_iam_role.lambda_exec.arn
  user_name = "lambda-remediation-bot"
  type = "STANDARD"
}

resource "kubernetes_role_v1" "lambda_remediation" {
  metadata {
    name = "lambda-remediation-role"
    namespace = "multitier-demo"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    resource_names = ["adminer"]
    verbs      = ["get", "list", "watch","patch"]
  }
}

resource "kubernetes_role_binding_v1" "lambda-remediation" {
  metadata {
    name = "lambda-remediation-binding"
    namespace = "multitier-demo"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "Role"
    name = kubernetes_role_v1.lambda_remediation.metadata[0].name
  }

  subject {
    kind = "User"
    name = "lambda-remediation-bot"
    api_group = "rbac.authorization.k8s.io"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role_policy" "lambda_bedrock" {
  name = "lambda-bedrock-invoke"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
         Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:UseInferenceProfile"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/amazon.nova-micro-v1:0",
          "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/eu.amazon.nova-micro-v1:0"
        ]
      }
    ]
  })
}