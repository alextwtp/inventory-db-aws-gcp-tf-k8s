variable "gcp_project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "asia-east1"
}

variable "app_name" {
  description = "Application Name"
  type        = string
  default     = "inventory-app"
}

variable "db_password" {
  description = "The password for the database user"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "The username for the database user"
  type        = string
  default     = "admin"
}

variable "image_url" {
  description = "The URL of the Docker image for the application"
  type        = string
  default     = "gcr.io/cloudrun/hello"
}