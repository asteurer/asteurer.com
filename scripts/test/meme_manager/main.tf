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

locals {
  tags = { environment = "dev" }
}

resource "aws_s3_bucket" "dev" {
  bucket = var.bucket_name
  force_destroy = true

  tags = local.tags
}

resource "aws_iam_user" "dev" {
  name = "dev_user"

  tags = local.tags
}

resource "aws_iam_group" "dev" {
  name = "asteurer.com_DEV"
}

data "aws_iam_policy_document" "bucket_permissions" {
  statement {
    sid = "BucketLevelPermissions"
    effect    = "Allow"
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.dev.arn]
  }

  statement {
    sid = "ObjectLevelPermissions"
    effect = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.dev.arn}/*"]
  }
}

resource "aws_iam_group_policy" "bucket_permissions" {
  name = "S3GetPutDelete"
  group = aws_iam_group.dev.name
  policy = data.aws_iam_policy_document.bucket_permissions.json
}

resource "aws_iam_access_key" "dev" {
  user = aws_iam_user.dev.name
}

output "access_key_id" {
  sensitive = true
  value = aws_iam_access_key.dev.id
}

output "secret_access_key" {
  sensitive = true
  value = aws_iam_access_key.dev.secret
}

resource "aws_iam_user_group_membership" "dev_user" {
  user = aws_iam_user.dev.name

  groups = [
    aws_iam_group.dev.name
  ]
}