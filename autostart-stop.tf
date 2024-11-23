resource "aws_iam_role" "lambda_role" {
  name               = "lambda_ec2_start_stop_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_start_stop_policy"
  description = "Policy to allow starting and stopping EC2 instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_lambda_function" "start_instances" {
  function_name = "start_ec2_instances"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  role = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256("start_instances.zip")

  # Create a zip file containing the following code:
  # import boto3
  # def lambda_handler(event, context):
  #     ec2 = boto3.client('ec2')
  #     ec2.start_instances(InstanceIds=['your-instance-id-1', 'your-instance-id-2'])
  #     return 'Started your instances'

  # Make sure to create start_instances.zip before running Terraform
}

resource "aws_lambda_function" "stop_instances" {
  function_name = "stop_ec2_instances"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  role = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256("stop_instances.zip")

  # Create a zip file containing the following code:
  # import boto3
  # def lambda_handler(event, context):
  #     ec2 = boto3.client('ec2')
  #     ec2.stop_instances(InstanceIds=['your-instance-id-1', 'your-instance-id-2'])
  #     return 'Stopped your instances'

  # Make sure to create stop_instances.zip before running Terraform
}

resource "aws_cloudwatch_event_rule" "start_rule" {
  name                = "start_ec2_rule"
  schedule_expression = "cron(0 8 * * ? *)" # Change to your desired schedule
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_rule.name
  target_id = "startEC2Instances"
  arn       = aws_lambda_function.start_instances.arn
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_rule.arn
}

resource "aws_cloudwatch_event_rule" "stop_rule" {
  name                = "stop_ec2_rule"
  schedule_expression = "cron(0 20 * * ? *)" # Change to your desired schedule
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  target_id = "stopEC2Instances"
  arn       = aws_lambda_function.stop_instances.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_rule.arn
}