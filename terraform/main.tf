terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.90.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# Variable for the application name
variable "app_name" {
  description = "The name of the application, used in the service name and subdomain"
  type        = string
  default     = "new-example-app-2"
}

# Reference the existing Route 53 hosted zone for eramapps.com
data "aws_route53_zone" "existing" {
  name = "eramapps.com"
}

# Create the App Runner service
resource "aws_apprunner_service" "example" {
  service_name = "${var.app_name}-apprunner-service"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access_role.arn
    }

    auto_deployments_enabled = false

    image_repository {
      image_configuration {
        port = "80"
      }
      image_identifier      = "975049989256.dkr.ecr.eu-central-1.amazonaws.com/new-ecr:17c9c72087953ae6d5451067f7a39a878808a5ef"
      image_repository_type = "ECR"
    }
  }
}

# Associate the custom subdomain with the App Runner service
resource "aws_apprunner_custom_domain_association" "example" {
  domain_name          = "${var.app_name}.eramapps.com"
  service_arn          = aws_apprunner_service.example.arn
  enable_www_subdomain = false
}

# Create DNS records for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_apprunner_custom_domain_association.example.certificate_validation_records : dvo.name => dvo
  }

  zone_id = data.aws_route53_zone.existing.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

# Create CNAME record to point the subdomain to the App Runner service
resource "aws_route53_record" "subdomain" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "${var.app_name}.eramapps.com"
  type    = "CNAME"
  records = [aws_apprunner_custom_domain_association.example.dns_target]
  ttl     = 300
}

# IAM role for App Runner to access ECR
resource "aws_iam_role" "apprunner_ecr_access_role" {
  name = "apprunner-ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

# Attach ECR access policy to the role
resource "aws_iam_role_policy_attachment" "apprunner_ecr_policy" {
  role       = aws_iam_role.apprunner_ecr_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Create S3 bucket for media and static files
resource "aws_s3_bucket" "media_bucket" {
  bucket = "${var.app_name}-media-bucket"
}

# Allow public access to the bucket's objects
resource "aws_s3_bucket_public_access_block" "media_bucket" {
  bucket = aws_s3_bucket.media_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Set bucket policy to allow public read access
resource "aws_s3_bucket_policy" "media_bucket" {
  bucket = aws_s3_bucket.media_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.media_bucket]
}

# CORS configuration for the media bucket
resource "aws_s3_bucket_cors_configuration" "media_bucket" {
  bucket = aws_s3_bucket.media_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers = []
    max_age_seconds = 3000
  }
}