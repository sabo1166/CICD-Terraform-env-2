# Partial backend configuration. Backend blocks cannot use variables, and the
# bucket name contains the AWS account ID, so bucket and region are supplied at
# init time and never committed:
#   terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=us-east-1"
#
# The key is what separates dev state from prod state.
terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3-native locking (Terraform >= 1.10); no DynamoDB table
  }
}
