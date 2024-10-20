terraform {
  required_providers {
   aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type = string
}

variable "bucket_name" {
    type = string
}

resource "aws_s3_bucket" "static_files" {
  bucket = var.bucket_name
  force_destroy = true
}
