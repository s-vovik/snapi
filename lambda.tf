resource "aws_lambda_function" "ec2_start" {
  filename         = "ec2_start.zip"
  function_name    = "ec2_start"
  role             = aws_iam_role.lambda_ec2_start_role.arn
  handler          = "ec2_start.lambda_handler"
  source_code_hash = "${base64sha256(filebase64sha256("ec2_start.zip"))}"
  runtime          = "python3.8"
  timeout          = 600

  environment {
    variables = {
      EC2_INSTANCE  = aws_instance.qiime.id
    }
  }
}

resource "aws_iam_role" "lambda_ec2_start_role" {
  name = "EC2Role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_ec2_start_role_policy" {
  name = "LambdaEC2StartRolePolicy"
  role = "${aws_iam_role.lambda_ec2_start_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_rule" "every3hours" {
  name                = "3hours"
  schedule_expression = "${var.schedule}"
  is_enabled          = "true"
}

resource "aws_cloudwatch_event_target" "twich_every3hour" {
  rule      = "${aws_cloudwatch_event_rule.every3hours.name}"
  target_id = "ec2_start"
  arn       = "${aws_lambda_function.ec2_start.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_ec2_start" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ec2_start.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every3hours.arn}"
}