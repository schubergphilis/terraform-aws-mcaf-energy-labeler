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

  image_uri = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/energy-labeler:latest"

  config = {
    export_path             = "s3://bucket_name/folder/"
    organizations_zone_name = "MYZONE"
  }
}
