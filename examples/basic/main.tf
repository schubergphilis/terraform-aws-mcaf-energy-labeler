terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.39.0"
    }
  }
}

provider "aws" {}

module "aws-energy-labeler-single-account" {
  source = "../../"

  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    single_account_id = "123456789012"
  }
}

module "aws-energy-labeler-zone" {
  source = "../../"

  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-123456789012"

  config = {
    zone_name = "MYZONE"
  }
}
