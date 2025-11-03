output "namespace" {
  description = "Namespace for pudim.dev domain"
  value       = kubernetes_namespace.pudim_dev.metadata[0].name
}

output "service_name" {
  description = "Service name for pudim.dev site"
  value       = module.pudim_dev_site.service_name
}

output "site_url" {
  description = "URL for pudim.dev site"
  value       = "https://pudim.dev"
}

