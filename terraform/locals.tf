locals {
  account_id = data.aws_caller_identity.this.account_id
  tags = {
    Environment = var.environment
    Managed-By  = "Terraform"
  }
}
