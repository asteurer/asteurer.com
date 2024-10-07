#################################################################################
# Providers
#################################################################################

terraform {
  required_providers {
   aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

#################################################################################
# Variables
#################################################################################

variable "aws_region" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "cloudflare_domain" {
    type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

locals {
  name_tag = {"Name" = "${var.cloudflare_domain}"}
}

#################################################################################
# EC2 Instances
#################################################################################

#--------------------------------------------------------------------------------
# Misc
#--------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "dev" {
    key_name   = var.cloudflare_domain
    public_key = var.ssh_public_key

    tags       = local.name_tag
}

#--------------------------------------------------------------------------------
# Networking
#--------------------------------------------------------------------------------

resource "aws_vpc" "dev" {
  cidr_block = "10.0.0.0/16"

  tags       = local.name_tag
}

resource "aws_subnet" "dev" {
  vpc_id            = aws_vpc.dev.id
  availability_zone = "${var.aws_region}a"
  cidr_block        = "10.0.0.0/24"

  tags              =  local.name_tag
}

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id

  tags   =  local.name_tag

}

resource "aws_route_table" "dev" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id
  }

  tags =  local.name_tag

}

resource "aws_route_table_association" "dev" {
  subnet_id      = aws_subnet.dev.id
  route_table_id = aws_route_table.dev.id
}

#--------------------------------------------------------------------------------
# SERVER: K3S Master Node
#--------------------------------------------------------------------------------

resource "aws_instance" "master_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3a.small"
  key_name                    = aws_key_pair.dev.key_name
  associate_public_ip_address = true
  private_ip                  = "10.0.0.4"
  subnet_id                   = aws_subnet.dev.id
  vpc_security_group_ids      = [aws_security_group.sg_master_node.id]

  tags = {
    "Name" = "${var.cloudflare_domain}-master-node"
  }
}

output "master_node_ip" {
  value = aws_instance.master_node.public_ip
}

resource "aws_security_group" "sg_master_node" {
  description = "Allow SSH, HTTP, and HTTPS from anywhere"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow for access to the KubeAPI Server
  ingress {
    description = "HTTP"
    from_port   = "6443"
    to_port     = "6443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = "30080"
    to_port     = "30080"
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.dev.cidr_block]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.dev.cidr_block]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.dev.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "sg-${var.cloudflare_domain}-master-node"
  }
}

#--------------------------------------------------------------------------------
# SERVER: NGINX
#--------------------------------------------------------------------------------

resource "aws_instance" "nginx" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3a.nano"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.dev.key_name
  subnet_id                   = aws_subnet.dev.id
  vpc_security_group_ids      = [aws_security_group.sg_nginx.id]

  tags = {
    "Name" = "${var.cloudflare_domain}-nginx"
  }
}

output "nginx_node_ip" {
  value = aws_instance.nginx.public_ip
}

resource "aws_security_group" "sg_nginx" {
  description = "Allow SSH, HTTP, and HTTPS from anywhere"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "sg-${var.cloudflare_domain}-nginx"
  }
}

#################################################################################
# S3 Bucket
#################################################################################

resource "aws_s3_bucket" "static_files" {
  bucket = "${var.cloudflare_domain}-static-files"
  force_destroy = true
}

# Configure public access settings
resource "aws_s3_bucket_public_access_block" "static_files" {
  bucket = aws_s3_bucket.static_files.id

  # Block all public ACLs
  block_public_acls       = true
  ignore_public_acls      = true

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
# DNS Records
#################################################################################

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = aws_instance.nginx.public_ip
  type    = "A"
  ttl     = 300

  depends_on = [ aws_instance.nginx ]
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = aws_instance.nginx.public_ip
  type    = "A"
  ttl     = 300

  depends_on = [ aws_instance.nginx ]
}