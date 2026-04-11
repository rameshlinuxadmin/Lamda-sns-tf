terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

################################
# SNS Topic + Email Subscription
################################
resource "aws_sns_topic" "ec2_running" {
  name = "ec2-running-notification"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ec2_running.arn
  protocol  = "email"
  endpoint  = var.email_address
}

#############################
# IAM Role for Lambda
#############################
resource "aws_iam_role" "lambda_role" {
  name = "lambda-ec2-running-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-ec2-running-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.ec2_running.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

#############################
# Lambda Function
#############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "ec2_notify" {
  function_name = "ec2-running-notification"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.ec2_running.arn
    }
  }
}

#############################
# EventBridge Rule
#############################
resource "aws_cloudwatch_event_rule" "ec2_running_rule" {
  name = "ec2-instance-running-rule"

  event_pattern = jsonencode({
    source = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["running"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_running_rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.ec2_notify.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_notify.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_running_rule.arn
}


resource "aws_lambda_function_event_invoke_config" "lambda_dest" {
  function_name = aws_lambda_function.ec2_notify.function_name

  destination_config {
    on_success {
      destination = aws_sns_topic.ec2_running.arn
    }
  }
}
