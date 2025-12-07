variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ringo"
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

variable "allowed_cors_origins" {
  description = "List of allowed CORS origins for media bucket"
  type        = list(string)
  default     = []
}

