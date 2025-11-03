# Create a dedicated namespace for the Cloudflare Tunnel
resource "kubernetes_namespace" "cloudflare_tunnel" {
  count = var.cloudflare_tunnel_token != "" ? 1 : 0

  metadata {
    name = "cloudflare-tunnel"
    labels = {
      name        = "cloudflare-tunnel"
      managed-by  = "terraform"
    }
  }
}

# Deploy the shared Cloudflare Tunnel
module "cloudflare_tunnel" {
  count = var.cloudflare_tunnel_token != "" ? 1 : 0
  
  source = "./modules/cloudflare-tunnel"
  
  tunnel_token = var.cloudflare_tunnel_token
  namespace    = kubernetes_namespace.cloudflare_tunnel[0].metadata[0].name

  depends_on = [kubernetes_namespace.cloudflare_tunnel]
}

# Orchestrate all domain deployments
# Each domain has its own module in domains/ folder

# Deploy pudim.dev domain
module "pudim_dev" {
  source = "./domains/pudim-dev"
  
  enable_nfs_storage       = var.enable_nfs_storage
  storage_class            = var.storage_class
}

# Deploy luismachadoreis.dev domain
module "luismachadoreis_dev" {
  source = "./domains/luismachadoreis-dev"
  
  enable_nfs_storage = var.enable_nfs_storage
  storage_class      = var.storage_class
}

# Deploy carimbo.vip domain
module "carimbo_vip" {
  source = "./domains/carimbo-vip"
  
  enable_nfs_storage = var.enable_nfs_storage
  storage_class      = var.storage_class
}
