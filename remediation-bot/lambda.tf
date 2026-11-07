data "archive_file" "remediate_zip" {
  type = "zip"
  source_dir = "${path.module}/functions/remediate"
  output_path = "${path.module}/functions/remediate.zip"
}

resource "aws_lambda_function" "remediate" {
  function_name = "aiops-remediate-adminer"
  filename = data.archive_file.remediate_zip.output_path
  source_code_hash = data.archive_file.remediate_zip.output_base64sha256
  handler = "remediate.handler"
  runtime = "python3.12"
  role = aws_iam_role.lambda_exec.arn
  timeout = 90


  environment {
    variables = {
      CLUSTER_NAME = data.aws_eks_cluster.main.name
      CLUSTER_ENDPOINT = data.aws_eks_cluster.main.endpoint
      CLUSTER_CA       = data.aws_eks_cluster.main.certificate_authority[0].data
      NAMESPACE = "multitier-demo"
      TARGET_DEPLOYMENT = "adminer"
      MODEL_ID = "eu.amazon.nova-micro-v1:0"
      COOLDOWN_SECONDS = "900"
    }
  }
}