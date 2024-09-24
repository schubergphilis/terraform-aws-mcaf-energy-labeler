provider "aws" {
  region = "eu-west-1"
}

module "aws-energy-labeler" {
  source = "../../"

  image_uri   = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/energy-labeler:latest"
  kms_key_arn = module.kms_key.arn

  labeler_config = {
    export-path             = "s3://bucket-name/folder/"
    organizations-zone-name = "SOMETHING"
  }
}
