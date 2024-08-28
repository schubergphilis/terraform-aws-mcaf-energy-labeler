provider "aws" {
  region = "eu-west-1"
}

module "aws-energy-labeler" {
  source = "../../"

  kms_key_arn = module.kms_key.arn
  labeler_config = {
    organizations-zone-name = "SOMETHING"
    export-path             = "s3://bucket-name/folder/"
  }
}
