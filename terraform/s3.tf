# ─── S3 Buckets ────────────────────────────────────────────────────────

# 1. Static assets / product images
resource "aws_s3_bucket" "assets" {
  bucket = "${var.project_name}-assets-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-assets"
    Purpose = "product-images-static-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.assets.arn}/*"
    }]
  })
}

# 2. Terraform state backend bucket + DynamoDB lock table
#    (created by Terraform itself once the backend block is uncommented,
#     or pre-created manually)

resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-tf-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project_name}-tf-state"
    Purpose = "terraform-state-backend"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "${var.project_name}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "${var.project_name}-tf-locks"
    Purpose = "terraform-state-locks"
  }
}

# ─── Data sources ──────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
