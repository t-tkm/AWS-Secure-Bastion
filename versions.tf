terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "secure-bastion-terraform-tfstate"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}