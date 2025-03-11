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

resource "aws_apprunner_service" "example" {
  service_name = "example-apprunner-service"

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