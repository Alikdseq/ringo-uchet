terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  
  # Опционально: использовать remote backend для state файла
  # backend "s3" {
  #   bucket = "ringo-terraform-state"
  #   key    = "infrastructure/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "digitalocean" {
  token = var.do_token
}

# VPC для изоляции ресурсов
resource "digitalocean_vpc" "ringo_vpc" {
  name     = "ringo-vpc-${var.environment}"
  region   = var.region
  ip_range = var.vpc_ip_range
}

# Управляемая PostgreSQL база данных
resource "digitalocean_database_cluster" "ringo_postgres" {
  name       = "ringo-postgres-${var.environment}"
  engine     = "pg"
  version    = "15"
  size       = var.db_size
  region     = var.region
  node_count = var.db_node_count
  
  maintenance_window {
    day  = "sunday"
    hour = "03:00"
  }
  
  tags = ["ringo", "database", var.environment]
  
  # Backup настройки
  backup_restore {
    database_name = "ringo"
  }
}

# Управляемый Redis для Celery и кэширования
resource "digitalocean_database_cluster" "ringo_redis" {
  name       = "ringo-redis-${var.environment}"
  engine     = "redis"
  version    = "7"
  size       = var.redis_size
  region     = var.region
  node_count = 1
  
  maintenance_window {
    day  = "sunday"
    hour = "04:00"
  }
  
  tags = ["ringo", "cache", var.environment]
}

# Spaces (S3-совместимое хранилище) для файлов
resource "digitalocean_spaces_bucket" "ringo_storage" {
  name   = "ringo-storage-${var.environment}"
  region = var.region
  
  # Версионирование для backup
  versioning {
    enabled = true
  }
  
  # Lifecycle policy для автоматической очистки старых версий
  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      days = 30
    }
  }
  
  cors_rule {
    allowed_origins = var.allowed_cors_origins
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 3600
  }
}

# Firewall правила
resource "digitalocean_firewall" "ringo_firewall" {
  name = "ringo-firewall-${var.environment}"
  
  # Разрешаем HTTP/HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # Разрешаем SSH только с определенных IP (опционально)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_ips
  }
  
  # Разрешаем все исходящие соединения
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  tags = ["ringo", var.environment]
}

# Load Balancer для распределения нагрузки
resource "digitalocean_loadbalancer" "ringo_lb" {
  name   = "ringo-lb-${var.environment}"
  region = var.region
  
  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"
    
    target_port     = 8000
    target_protocol = "http"
  }
  
  forwarding_rule {
    entry_port     = 443
    entry_protocol = "https"
    
    target_port     = 8000
    target_protocol = "http"
    
    certificate_name = digitalocean_certificate.ringo_cert.name
  }
  
  healthcheck {
    port     = 8000
    protocol = "http"
    path     = "/api/health/"
  }
  
  droplet_ids = digitalocean_droplet.ringo_api[*].id
  
  redirect_http_to_https = true
  
  tags = ["ringo", "loadbalancer", var.environment]
}

# SSL сертификат (Let's Encrypt)
resource "digitalocean_certificate" "ringo_cert" {
  name    = "ringo-cert-${var.environment}"
  type    = "lets_encrypt"
  domains = var.domains
  
  lifecycle {
    create_before_destroy = true
  }
}

# Droplets для API сервера (можно масштабировать)
resource "digitalocean_droplet" "ringo_api" {
  count  = var.api_instance_count
  name   = "ringo-api-${var.environment}-${count.index + 1}"
  image  = var.droplet_image
  region = var.region
  size   = var.api_instance_size
  
  vpc_uuid = digitalocean_vpc.ringo_vpc.id
  
  ssh_keys = var.ssh_key_ids
  
  user_data = templatefile("${path.module}/templates/api-init.sh", {
    db_host     = digitalocean_database_cluster.ringo_postgres.host
    db_port     = digitalocean_database_cluster.ringo_postgres.port
    db_name     = digitalocean_database_cluster.ringo_postgres.database
    redis_host  = digitalocean_database_cluster.ringo_redis.host
    redis_port  = digitalocean_database_cluster.ringo_redis.port
    s3_endpoint = "${digitalocean_spaces_bucket.ringo_storage.region}.digitaloceanspaces.com"
    s3_bucket   = digitalocean_spaces_bucket.ringo_storage.name
    environment = var.environment
  })
  
  tags = ["ringo", "api", var.environment]
}

# Droplets для Celery workers (можно масштабировать отдельно)
resource "digitalocean_droplet" "ringo_worker" {
  count  = var.worker_instance_count
  name   = "ringo-worker-${var.environment}-${count.index + 1}"
  image  = var.droplet_image
  region = var.region
  size   = var.worker_instance_size
  
  vpc_uuid = digitalocean_vpc.ringo_vpc.id
  
  ssh_keys = var.ssh_key_ids
  
  user_data = templatefile("${path.module}/templates/worker-init.sh", {
    db_host     = digitalocean_database_cluster.ringo_postgres.host
    db_port     = digitalocean_database_cluster.ringo_postgres.port
    db_name     = digitalocean_database_cluster.ringo_postgres.database
    redis_host  = digitalocean_database_cluster.ringo_redis.host
    redis_port  = digitalocean_database_cluster.ringo_redis.port
    s3_endpoint = "${digitalocean_spaces_bucket.ringo_storage.region}.digitaloceanspaces.com"
    s3_bucket   = digitalocean_spaces_bucket.ringo_storage.name
    environment = var.environment
    worker_concurrency = var.celery_worker_concurrency
  })
  
  tags = ["ringo", "worker", var.environment]
}

# Применяем firewall ко всем droplets
resource "digitalocean_firewall" "ringo_droplets_firewall" {
  name = "ringo-droplets-firewall-${var.environment}"
  
  droplet_ids = concat(
    digitalocean_droplet.ringo_api[*].id,
    digitalocean_droplet.ringo_worker[*].id
  )
  
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_ips
  }
  
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8000"
    source_addresses = [digitalocean_vpc.ringo_vpc.ip_range]
  }
  
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Outputs
output "vpc_id" {
  value       = digitalocean_vpc.ringo_vpc.id
  description = "VPC ID"
}

output "database_host" {
  value       = digitalocean_database_cluster.ringo_postgres.host
  description = "PostgreSQL host"
  sensitive   = true
}

output "database_port" {
  value       = digitalocean_database_cluster.ringo_postgres.port
  description = "PostgreSQL port"
}

output "redis_host" {
  value       = digitalocean_database_cluster.ringo_redis.host
  description = "Redis host"
  sensitive   = true
}

output "redis_port" {
  value       = digitalocean_database_cluster.ringo_redis.port
  description = "Redis port"
}

output "spaces_endpoint" {
  value       = "${digitalocean_spaces_bucket.ringo_storage.region}.digitaloceanspaces.com"
  description = "Spaces endpoint"
}

output "spaces_bucket" {
  value       = digitalocean_spaces_bucket.ringo_storage.name
  description = "Spaces bucket name"
}

output "load_balancer_ip" {
  value       = digitalocean_loadbalancer.ringo_lb.ip
  description = "Load balancer IP address"
}

output "api_instances" {
  value = {
    for idx, instance in digitalocean_droplet.ringo_api :
    instance.name => instance.ipv4_address
  }
  description = "API instances IP addresses"
}

output "worker_instances" {
  value = {
    for idx, instance in digitalocean_droplet.ringo_worker :
    instance.name => instance.ipv4_address
  }
  description = "Worker instances IP addresses"
}

