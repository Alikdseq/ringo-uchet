# Terraform конфигурация для S3 бэкапов с версионированием
# Lifecycle policy отложена - можно добавить позже при необходимости

resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-backups-${var.environment}"
  
  tags = {
    Name        = "${var.project_name}-backups-${var.environment}"
    Environment = var.environment
    Purpose     = "backups"
  }
}

# Версионирование S3
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Шифрование
resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Блокировка публичного доступа
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}

# Lifecycle policy отложена - можно добавить позже при необходимости
# Версионирование включено выше, этого достаточно для начала

# IAM policy для доступа к бэкапам
resource "aws_iam_policy" "backup_access" {
  name        = "${var.project_name}-backup-access-${var.environment}"
  description = "Policy for backup access to S3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.backups.arn}",
          "${aws_s3_bucket.backups.arn}/*"
        ]
      }
    ]
  })
}

# Outputs
output "backup_bucket_name" {
  value       = aws_s3_bucket.backups.id
  description = "Name of the backup S3 bucket"
}

output "backup_bucket_arn" {
  value       = aws_s3_bucket.backups.arn
  description = "ARN of the backup S3 bucket"
}

