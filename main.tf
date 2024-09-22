resource "digitalocean_droplet" "demo_server" {
  image  = "ubuntu-22-04-x64"
  name   = "demo-server"
  region = "sfo2"
  size   = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_key_fingerprint]
  user_data = file("init.yaml")
}

output "droplet_ipv4" {
  value = digitalocean_droplet.demo_server.ipv4_address
}

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = digitalocean_droplet.demo_server.ipv4_address
  type    = "A"
  ttl     = 300

  depends_on = [ digitalocean_droplet.demo_server ]
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = digitalocean_droplet.demo_server.ipv4_address
  type    = "A"
  ttl     = 300

  depends_on = [ digitalocean_droplet.demo_server ]
}

resource "aws_s3_bucket" "static_files" {
  bucket = "${var.domain}-static-files"
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

resource "aws_s3_object" "meme" {
  bucket = aws_s3_bucket.static_files.bucket
  key    = "meme.jpg"
  source = "static_files/meme.jpg"
  content_type = "image/jpeg"

  depends_on = [ aws_s3_bucket_public_access_block.static_files ]
}

resource "aws_s3_object" "resume" {
  bucket = aws_s3_bucket.static_files.bucket
  key    = "resume.pdf"
  source = "static_files/resume.pdf"
  content_type = "application/pdf"

  depends_on = [ aws_s3_bucket_public_access_block.static_files ]
}