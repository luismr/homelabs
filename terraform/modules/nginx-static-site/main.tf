# PersistentVolumeClaim for site content
resource "kubernetes_persistent_volume_claim" "site_content" {
  count = var.enable_nfs ? 1 : 0
  
  metadata {
    name      = "${var.site_name}-content"
    namespace = var.namespace
    labels = {
      app         = var.site_name
      domain      = var.domain
      environment = var.environment
      managed-by  = "terraform"
    }
  }
  
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = var.storage_class
    
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

# ConfigMap with default index.html
resource "kubernetes_config_map" "default_content" {
  metadata {
    name      = "${var.site_name}-default-content"
    namespace = var.namespace
    labels = {
      app         = var.site_name
      domain      = var.domain
      environment = var.environment
      managed-by  = "terraform"
    }
  }
  
  data = {
    "index.html" = <<-EOF
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${var.domain}</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
          }
          .container {
            text-align: center;
            padding: 2rem;
          }
          h1 {
            font-size: 3rem;
            margin: 0 0 1rem 0;
            animation: fadeIn 1s ease-in;
          }
          p {
            font-size: 1.2rem;
            opacity: 0.9;
          }
          .domain {
            background: rgba(255, 255, 255, 0.2);
            padding: 0.5rem 1rem;
            border-radius: 8px;
            display: inline-block;
            margin-top: 1rem;
            font-family: 'Courier New', monospace;
          }
          @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🚀 Welcome!</h1>
          <p>Your site is live and running on Kubernetes</p>
          <div class="domain">${var.domain}</div>
        </div>
      </body>
      </html>
    EOF
  }
}

# Deployment
resource "kubernetes_deployment" "site" {
  metadata {
    name      = var.site_name
    namespace = var.namespace
    labels = {
      app         = var.site_name
      domain      = var.domain
      environment = var.environment
      managed-by  = "terraform"
    }
  }
  
  spec {
    replicas = var.replicas
    
    selector {
      match_labels = {
        app = var.site_name
      }
    }
    
    template {
      metadata {
        labels = {
          app         = var.site_name
          domain      = var.domain
          environment = var.environment
        }
      }
      
      spec {
        # Init container to copy default content if NFS volume is empty
        init_container {
          name  = "init-content"
          image = "busybox:latest"
          
          command = [
            "sh",
            "-c",
            <<-EOF
              if [ ! -f /usr/share/nginx/html/index.html ]; then
                echo "Copying default content..."
                cp /default-content/index.html /usr/share/nginx/html/
              else
                echo "Content already exists, skipping..."
              fi
            EOF
          ]
          
          volume_mount {
            name       = "content"
            mount_path = "/usr/share/nginx/html"
          }
          
          volume_mount {
            name       = "default-content"
            mount_path = "/default-content"
          }
        }
        
        container {
          name  = "nginx"
          image = var.nginx_image
          
          port {
            container_port = 80
            protocol       = "TCP"
          }
          
          volume_mount {
            name       = "content"
            mount_path = "/usr/share/nginx/html"
          }
          
          resources {
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
          }
          
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
          
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
        
        volume {
          name = "content"
          
          dynamic "persistent_volume_claim" {
            for_each = var.enable_nfs ? [1] : []
            content {
              claim_name = kubernetes_persistent_volume_claim.site_content[0].metadata[0].name
            }
          }
          
          dynamic "empty_dir" {
            for_each = var.enable_nfs ? [] : [1]
            content {}
          }
        }
        
        volume {
          name = "default-content"
          config_map {
            name = kubernetes_config_map.default_content.metadata[0].name
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "site" {
  metadata {
    name      = var.site_name
    namespace = var.namespace
    labels = {
      app         = var.site_name
      domain      = var.domain
      environment = var.environment
      managed-by  = "terraform"
    }
    annotations = {
      "cloudflare-tunnel/hostname" = var.domain
    }
  }
  
  spec {
    selector = {
      app = var.site_name
    }
    
    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}

