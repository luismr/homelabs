variable "site_name" {
  description = "Name of the site (used for resource naming)"
  type        = string
}

variable "domain" {
  description = "Domain name for the site"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  default     = "development"
}

variable "replicas" {
  description = "Number of nginx replicas"
  type        = number
  default     = 2
}

variable "enable_nfs" {
  description = "Enable NFS persistent storage"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "StorageClass to use for persistent volume"
  type        = string
  default     = "nfs-client"
}

variable "storage_size" {
  description = "Size of persistent volume"
  type        = string
  default     = "1Gi"
}

variable "nginx_image" {
  description = "Nginx Docker image"
  type        = string
  default     = "nginx:alpine"
}

variable "resource_limits_cpu" {
  description = "CPU limit for nginx container"
  type        = string
  default     = "100m"
}

variable "resource_limits_memory" {
  description = "Memory limit for nginx container"
  type        = string
  default     = "128Mi"
}

variable "resource_requests_cpu" {
  description = "CPU request for nginx container"
  type        = string
  default     = "50m"
}

variable "resource_requests_memory" {
  description = "Memory request for nginx container"
  type        = string
  default     = "64Mi"
}

