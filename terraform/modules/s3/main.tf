# Data Lake S3 Bucket
resource "aws_s3_bucket" "data_lake" {
  bucket = var.data_lake_bucket_name

  tags = {
    Name        = var.data_lake_bucket_name
    Environment = var.environment
    Project     = var.project
    Purpose     = "data-lake"
    DataType    = "mixed"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = var.data_lake_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake_encryption" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "data_lake_public_access_block" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "data_lake_lifecycle" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "raw_data_lifecycle"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.data_lake_lifecycle_days
    }
  }

  rule {
    id     = "processed_data_lifecycle"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 60
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = var.data_lake_lifecycle_days * 2  # Keep processed data longer
    }
  }

  rule {
    id     = "temp_data_lifecycle"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 7  # Delete temp data after 7 days
    }
  }

  rule {
    id     = "glue_scripts_lifecycle"
    status = "Enabled"

    filter {
      prefix = "glue_scripts/"
    }

    # Keep scripts indefinitely (no expiration)
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

# Create folder structure
resource "aws_s3_object" "raw_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/"
  source = "/dev/null"
}

resource "aws_s3_object" "processed_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "processed/"
  source = "/dev/null"
}

resource "aws_s3_object" "glue_scripts_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "glue_scripts/"
  source = "/dev/null"
}


resource "aws_s3_object" "archive_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "archive/"
  source = "/dev/null"
}

resource "aws_s3_object" "logs_folder" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "logs/"
  source = "/dev/null"
}