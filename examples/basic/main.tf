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

  config = {
    zone_name = "MYZONE"
  }
}
