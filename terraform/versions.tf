# ─── Providers ──────────────────────────────────────────────────────
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner_email
    }
  }
}

# ─── Terraform State Backend (S3 + DynamoDB lock) ──────────────────
# Run `terraform init` after creating the backend bucket manually once,
# or remove the backend block and let state live locally during dev.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment after you create the backend S3 bucket + DynamoDB table.
  # backend "s3" {
  #   bucket         = "myshoe-tf-state"
  #   key            = "terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "myshoe-tf-locks"
  #   encrypt        = true
  # }
}
