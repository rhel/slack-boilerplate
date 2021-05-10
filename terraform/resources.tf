resource "aws_kinesis_stream" "this" {
  name = "${var.environment}-boilerplate"
  lifecycle {
    ignore_changes = [
      shard_count
    ]
  }
  shard_count      = 1
  retention_period = 48

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  tags = local.tags
}

data "archive_file" "this" {
  for_each = toset([
    "boilerplate",
  ])
  depends_on = [
    null_resource.layers,
  ]
  output_path = "../sources/${each.key}.zip"
  source_file = "../sources/${each.key}/${each.key}"
  type        = "zip"
}

data "aws_caller_identity" "this" {}

resource "null_resource" "layers" {
  for_each = toset([
    "boilerplate",
  ])
  provisioner "local-exec" {
    working_dir = "../sources/"
    command     = "./build-go.sh ${each.key}"
  }
  triggers = {
    always_run = timestamp()
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ])
  role       = aws_iam_role.boilerplate.name
  policy_arn = each.key
}

resource "aws_iam_role" "boilerplate" {
  name                 = "${var.environment}-boilerplate"
  max_session_duration = 3600
  description          = "The boilerplate IAM role."
  assume_role_policy   = data.aws_iam_policy_document.this.json
  inline_policy {
    name = "Kinesis"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "kinesis:*",
          ]
          Effect   = "Allow"
          Resource = aws_kinesis_stream.this.arn
        },
        {
          Action = [
            "kinesis:ListStreams",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
  tags = local.tags
}

resource "aws_api_gateway_deployment" "this" {
  lifecycle {
    create_before_destroy = true
  }
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.boilerplate.id,
      aws_api_gateway_method.boilerplate.id,
      aws_api_gateway_integration.boilerplate.id,
    ]))
  }
  rest_api_id = aws_api_gateway_rest_api.this.id
}

resource "aws_api_gateway_integration" "boilerplate" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_method.boilerplate.resource_id
  http_method = aws_api_gateway_method.boilerplate.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.boilerplate.invoke_arn
}

resource "aws_api_gateway_method" "boilerplate" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.boilerplate.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "boilerplate" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "boilerplate"
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${var.environment}-boilerplate"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = local.tags
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.environment
  tags          = local.tags
}

resource "aws_lambda_function" "boilerplate" {
  function_name    = "${var.environment}-boilerplate"
  source_code_hash = data.archive_file.this["boilerplate"].output_base64sha256
  filename         = data.archive_file.this["boilerplate"].output_path
  handler          = "boilerplate"
  environment {
    variables = {
      SLACK_SIGNING_SECRET = var.slack_signing_secret
    }
  }
  runtime = "go1.x"
  role    = aws_iam_role.boilerplate.arn
  tags    = local.tags
}

resource "aws_lambda_permission" "this" {
  for_each = toset([
    aws_lambda_function.boilerplate.function_name,
  ])

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.key
  principal     = "apigateway.amazonaws.com"

  # The /*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
