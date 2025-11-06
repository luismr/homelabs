locals {
  normalized_rules = [for r in var.rules : {
    sources = r.sources
    target  = r.target
    code    = try(r.code, 301)
  }]

  server_blocks = concat(
    flatten([
      for r in local.normalized_rules : concat(
        (
          [for s in r.sources : s if !startswith(s, "*.")]
          != []
        ) ? [
          join("\n", [
            "server {",
            "  listen 80;",
            format("  server_name %s;", join(" ", [for s in r.sources : s if !startswith(s, "*.")])) ,
            format("  return %d https://%s$request_uri;", r.code, r.target),
            "}",
          ])
        ] : [],
        [
          for s in r.sources : join("\n", [
            "server {",
            "  listen 80;",
            format("  server_name ~^(?<sub>.+)\\.%s$;", replace(s, "*.", "")),
            format("  return %d https://$sub.%s$request_uri;", r.code, r.target),
            "}",
          ]) if startswith(s, "*.")
        ]
      )
    ])
  )

  nginx_conf = join("\n\n", concat([
    "server {",
    "  listen 80 default_server;",
    "  server_name _;",
    "  return 444;",
    "}",
  ], local.server_blocks))
}

resource "kubernetes_config_map" "nginx" {
  metadata {
    name      = "${var.name}-conf"
    namespace = var.namespace
    labels = {
      app = var.name
    }
  }
  data = {
    "default.conf" = local.nginx_conf
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      app = var.name
    }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.name
      }
    }
    template {
      metadata {
        labels = {
          app = var.name
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:stable-alpine"

          port {
            name           = "http"
            container_port = 80
          }

          readiness_probe {
            tcp_socket {
              port = 80
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          volume_mount {
            name       = "conf"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
            read_only  = true
          }
        }

        volume {
          name = "conf"
          config_map {
            name = kubernetes_config_map.nginx.metadata[0].name
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = "redirector"
    namespace = var.namespace
    labels = {
      app = var.name
    }
  }
  spec {
    selector = {
      app = var.name
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

resource "kubernetes_horizontal_pod_autoscaler_v2" "this" {
  metadata {
    name      = "${var.name}-hpa"
    namespace = var.namespace
    labels = {
      app = var.name
    }
  }
  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.this.metadata[0].name
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.target_cpu_utilization_percentage
        }
      }
    }
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = var.target_memory_utilization_percentage
        }
      }
    }
  }
}


