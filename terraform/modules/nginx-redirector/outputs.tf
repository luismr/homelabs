output "service_name" {
  value = kubernetes_service.this.metadata[0].name
}

output "namespace" {
  value = var.namespace
}


