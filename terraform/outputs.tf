output "boilerplate_url" {
  value = format(
    "https://%s.execute-api.%s.amazonaws.com/%s%s",
    aws_api_gateway_rest_api.this.id,
    var.aws_region,
    var.environment,
    aws_api_gateway_resource.boilerplate.path
  )
}
