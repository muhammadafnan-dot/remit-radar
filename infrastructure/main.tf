terraform{
    backend "s3" {
        bucket = "remit-radar-terraform-state"
        key = "prod/terraform.tfstate"
        region = "eu-central-1"
    }
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}
provider "aws" {
    region = "eu-central-1"
    profile = var.aws_profile
}