terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.39.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "aws-energy-labeler" {
  source = "../../"

  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    zone_name = "MYZONE"
  }
}
