# Simple data storage bucket
resource "aws_s3_bucket" "raw_storage_bucket" {
  bucket = var.raw_storage_bucket_name

  tags = {
    Name        = var.raw_storage_bucket_name
    Environment = var.environment
    Project     = var.project
    Purpose     = "data-storage"
    DataType    = "raw-data"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_storage_encryption" {
  bucket = aws_s3_bucket.raw_storage_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "raw_storage_public_access_block" {
  bucket = aws_s3_bucket.raw_storage_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}