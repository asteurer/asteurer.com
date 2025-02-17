#################################################################################
# Providers
#################################################################################

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

variable "domain" {
  type = string
}

locals {
  name_tag = { "Name" = "${var.domain}" }
}


#################################################################################
# S3 Bucket
#################################################################################

resource "aws_s3_bucket" "static_files" {
  bucket        = "${var.domain}-prod"
  force_destroy = true
}

# Configure public access settings
resource "aws_s3_bucket_public_access_block" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  # Block all public ACLs
  block_public_acls  = true
  ignore_public_acls = true

  # Allow public bucket policies
  block_public_policy     = false
  restrict_public_buckets = false
}

# Attach a bucket policy to allow public read access
resource "aws_s3_bucket_policy" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  # Ensure public access settings are applied first
  depends_on = [aws_s3_bucket_public_access_block.static_files]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static_files.arn}/*"
      }
    ]
  })
}

output "s3_bucket_name" {
  value = aws_s3_bucket.static_files.bucket
}

#################################################################################
# IAM Service Account
#################################################################################

resource "aws_iam_user" "prod" {
  name = "prod_user"

  tags = local.name_tag
}

resource "aws_iam_group" "prod" {
  name = "${var.domain}_PROD"
}

data "aws_iam_policy_document" "bucket_permissions" {
  statement {
    sid       = "BucketLevelPermissions"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.static_files.arn]
  }

  statement {
    sid       = "ObjectLevelPermissions"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.static_files.arn}/*"]
  }
}

resource "aws_iam_group_policy" "bucket_permissions" {
  name   = "S3GetPutDelete"
  group  = aws_iam_group.prod.name
  policy = data.aws_iam_policy_document.bucket_permissions.json
}

resource "aws_iam_access_key" "prod" {
  user = aws_iam_user.prod.name
}

output "access_key_id" {
  sensitive = true
  value     = aws_iam_access_key.prod.id
}

output "secret_access_key" {
  sensitive = true
  value     = aws_iam_access_key.prod.secret
}

resource "aws_iam_user_group_membership" "prod_user" {
  user = aws_iam_user.prod.name

  groups = [
    aws_iam_group.prod.name
  ]
}