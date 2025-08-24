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
    id     = "bronze_data_lifecycle"
    status = "Enabled"
    filter { prefix = "bronze/" }

    transition {
      days          = min(30, var.data_lake_lifecycle_days)
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = min(90, var.data_lake_lifecycle_days)
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "silver_data_lifecycle"
    status = "Enabled"
    filter { prefix = "silver/" }

    transition {
      days          = min(60, var.data_lake_lifecycle_days)
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "gold_data_lifecycle"
    status = "Enabled"
    filter { prefix = "gold/" }

    # Keep gold data in standard (frequently accessed)
    transition {
      days          = min(180, var.data_lake_lifecycle_days)
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "temp_data_lifecycle"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 7
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
      days          = min(90, var.data_lake_lifecycle_days)
      storage_class = "STANDARD_IA"
    }
  }
}


# Create folder structure
resource "aws_s3_object" "bronze_folder" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "bronze/"
  content = ""

}

resource "aws_s3_object" "silver_folder" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "silver/"
  content = ""
}

resource "aws_s3_object" "gold_folder" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "gold/"
  content = ""
}

resource "aws_s3_object" "glue_scripts_folder" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "glue_scripts/"
  content = ""
}

resource "aws_s3_object" "logs_folder" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "logs/"
  content = ""
}


resource "aws_s3_object" "athena_results_folder" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "athena-results/"
  content = ""
}

# S3 notifications - triggering on bronze
resource "aws_s3_bucket_notification" "medallion_notification" {
  count  = var.enable_notifications && var.lambda_function_arn != "" ? 1 : 0
  bucket = aws_s3_bucket.data_lake.id

  lambda_function {
    lambda_function_arn = var.lambda_function_arn
    events              = ["s3:ObjectCreated:CompleteMultipartUpload", "s3:ObjectCreated:Put"]
    filter_prefix       = "bronze/"
    filter_suffix       = ".json"
  }
}
