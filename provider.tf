
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.49.0"
    }
  }
}

# provider here
provider "aws" {
  region = "eu-west-1"
  # Add credentials or authentication methods if needed
  # access_key = "YOUR_ACCESS_KEY"
  # secret_key = "YOUR_SECRET_KEY"
  # Alternatively, you can use a profile instead of access and secret keys:
  # profile    = "YOUR_AWS_PROFILE"

  default_tags {
    tags = {
      challenge = "nitro-sre"
    }
  }
 }
