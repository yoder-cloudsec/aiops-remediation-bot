data "aws_sns_topic" "alerts" {
  name = "eks-multitier-alerts"
}

resource "aws_sns_topic_subscription" "remediate" {
  topic_arn = data.aws_sns_topic.alerts.arn
  protocol = "lambda"
  endpoint = aws_lambda_function.remediate.arn
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id = "AllowSNSInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediate.function_name
  principal = "sns.amazonaws.com"
  source_arn = data.aws_sns_topic.alerts.arn
}