# Terraform конфигурация для S3 медиафайлов с версионированием
# Lifecycle policy отложена - можно добавить позже при необходимости

resource "aws_s3_bucket" "media" {
  bucket = "${var.project_name}-media-${var.environment}"
  
  tags = {
    Name        = "${var.project_name}-media-${var.environment}"
    Environment = var.environment
    Purpose     = "media-storage"
  }
}

# Версионирование для медиафайлов (фото, документы)
resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Шифрование
resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Блокировка публичного доступа
resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.media.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}

# Lifecycle policy отложена - можно добавить позже при необходимости
# Версионирование включено выше, этого достаточно для начала

# CORS конфигурация (если нужен доступ из браузера)
resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = var.allowed_cors_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

output "media_bucket_name" {
  value       = aws_s3_bucket.media.id
  description = "Name of the media S3 bucket"
}

output "media_bucket_arn" {
  value       = aws_s3_bucket.media.arn
  description = "ARN of the media S3 bucket"
}

