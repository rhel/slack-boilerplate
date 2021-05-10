variable "aws_region" {
  description = "The AWS Region"
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment name"
  default     = "prod"
}

variable "slack_signing_secret" {
  description = "The Slack Signing Secret"
  sensitive   = true
  default     = ""
}
