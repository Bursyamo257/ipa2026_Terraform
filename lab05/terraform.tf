terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket       = "ipa-tfstate-58b11137"
    key          = "lab05/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}