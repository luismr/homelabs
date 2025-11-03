# Secret for Cloudflare Tunnel token
resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "cloudflare-tunnel-token"
    namespace = var.namespace
    labels = {
      app        = "cloudflare-tunnel"
      managed-by = "terraform"
    }
  }
  
  data = {
    token = var.tunnel_token
  }
  
  type = "Opaque"
}

# ConfigMap for tunnel configuration
resource "kubernetes_config_map" "tunnel_config" {
  metadata {
    name      = "cloudflare-tunnel-config"
    namespace = var.namespace
    labels = {
      app        = "cloudflare-tunnel"
      managed-by = "terraform"
    }
  }
  
  data = {
    "config.yaml" = <<-EOF
      metrics: 0.0.0.0:2000
      no-autoupdate: true
      
      ingress:
        # pudim.dev -> static-site service in pudim-dev namespace
        - hostname: pudim.dev
          service: http://static-site.pudim-dev.svc.cluster.local:80
        - hostname: www.pudim.dev
          service: http://static-site.pudim-dev.svc.cluster.local:80
        
        # luismachadoreis.dev -> static-site service in luismachadoreis-dev namespace
        - hostname: luismachadoreis.dev
          service: http://static-site.luismachadoreis-dev.svc.cluster.local:80
        - hostname: www.luismachadoreis.dev
          service: http://static-site.luismachadoreis-dev.svc.cluster.local:80
        
        # carimbo.vip -> static-site service in carimbo-vip namespace
        - hostname: carimbo.vip
          service: http://static-site.carimbo-vip.svc.cluster.local:80
        - hostname: www.carimbo.vip
          service: http://static-site.carimbo-vip.svc.cluster.local:80
        
        # Catch-all rule (return 404 for unknown hosts)
        - service: http_status:404
    EOF
  }
}

# Deployment
resource "kubernetes_deployment" "tunnel" {
  metadata {
    name      = "cloudflare-tunnel"
    namespace = var.namespace
    labels = {
      app        = "cloudflare-tunnel"
      managed-by = "terraform"
    }
  }
  
  spec {
    replicas = var.replicas
    
    selector {
      match_labels = {
        app = "cloudflare-tunnel"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "cloudflare-tunnel"
        }
      }
      
      spec {
        container {
          name  = "cloudflared"
          image = var.image
          
          args = [
            "tunnel",
            "--config",
            "/etc/cloudflared/config.yaml",
            "run"
          ]
          
          port {
            name           = "metrics"
            container_port = 2000
            protocol       = "TCP"
          }
          
          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tunnel_credentials.metadata[0].name
                key  = "token"
              }
            }
          }
          
          volume_mount {
            name       = "config"
            mount_path = "/etc/cloudflared/config.yaml"
            sub_path   = "config.yaml"
            read_only  = true
          }
          
          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }
        
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.tunnel_config.metadata[0].name
          }
        }
      }
    }
  }
}

# Service for metrics
resource "kubernetes_service" "tunnel_metrics" {
  metadata {
    name      = "cloudflare-tunnel-metrics"
    namespace = var.namespace
    labels = {
      app        = "cloudflare-tunnel"
      managed-by = "terraform"
    }
  }
  
  spec {
    selector = {
      app = "cloudflare-tunnel"
    }
    
    port {
      name        = "metrics"
      port        = 2000
      target_port = 2000
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}

