terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.10.0"

  backend "s3" {
    key          = "terraform.tfstate"
    encrypt      = true
    use_lockfile = true
    # bucket, region, profile은 backend-main.hcl 에서 주입
    # terraform init -backend-config=backend-main.hcl
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

data "aws_availability_zones" "available" {
  state = "available"
}
