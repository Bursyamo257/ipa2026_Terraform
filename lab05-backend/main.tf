terraform {
  required_version = ">= 1.16.3"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.66.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "State bucket, created outside Terraform in Step 1.1"
}

# Requirement 1: RESILIENCY - keep every version of state
resource "aws_s3_bucket_versioning" "state" {
  bucket = var.bucket_name
  versioning_configuration {
    status = "Enabled"
  }
}

# Requirement 2: SECURITY - encrypt at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = var.bucket_name
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Requirement 3: SECURITY - never public
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = var.bucket_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" { value = var.bucket_name }
