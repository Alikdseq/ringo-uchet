variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  default     = "staging"
  
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "vpc_ip_range" {
  description = "VPC IP range (CIDR)"
  type        = string
  default     = "10.0.0.0/16"
}

# Database configuration
variable "db_size" {
  description = "Database cluster size slug"
  type        = string
  default     = "db-s-1vcpu-1gb"  # Для staging, для production использовать db-s-2vcpu-4gb или больше
}

variable "db_node_count" {
  description = "Number of database nodes"
  type        = number
  default     = 1  # Для production рекомендуется 2+ для high availability
}

# Redis configuration
variable "redis_size" {
  description = "Redis cluster size slug"
  type        = string
  default     = "db-s-1vcpu-1gb"
}

# Instance configuration
variable "droplet_image" {
  description = "Droplet image slug"
  type        = string
  default     = "docker-20-04"  # Ubuntu 20.04 с Docker
}

variable "api_instance_size" {
  description = "API instance size slug"
  type        = string
  default     = "s-2vcpu-4gb"  # 2 vCPU, 4GB RAM
}

variable "api_instance_count" {
  description = "Number of API instances"
  type        = number
  default     = 2  # Минимум 2 для high availability
}

variable "worker_instance_size" {
  description = "Worker instance size slug"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "worker_instance_count" {
  description = "Number of worker instances"
  type        = number
  default     = 2
}

variable "celery_worker_concurrency" {
  description = "Celery worker concurrency (number of worker processes)"
  type        = number
  default     = 4
}

# Security
variable "ssh_key_ids" {
  description = "List of SSH key IDs to add to droplets"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # В production ограничить до конкретных IP
}

variable "allowed_cors_origins" {
  description = "List of allowed CORS origins for Spaces"
  type        = list(string)
  default     = ["*"]  # В production указать конкретные домены
}

# Domains
variable "domains" {
  description = "List of domains for SSL certificate"
  type        = list(string)
  default     = []
}

