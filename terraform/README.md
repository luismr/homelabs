# Terraform Infrastructure for Kubernetes

This directory contains Terraform configurations to manage Kubernetes deployments for static websites with Cloudflare Tunnel integration.

## Overview

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Cloudflare Network                        │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐         │
│  │ pudim.dev  │   │luismachado │   │carimbo.vip │         │
│  │            │   │  reis.dev  │   │            │         │
│  └──────┬─────┘   └──────┬─────┘   └──────┬─────┘         │
│         │                │                │                 │
│         └────────────────┼────────────────┘                 │
│                          │                                  │
│                  Cloudflare Tunnel                          │
└──────────────────────────┼──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                  Kubernetes Cluster                          │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Namespace: pudim-dev             (Production)        │  │
│  │  ┌─────────────┐   ┌──────────┐   ┌────────────┐   │  │
│  │  │ Deployment  │──▶│ Service  │   │ PVC (NFS)  │   │  │
│  │  │ (nginx x3)  │   │ClusterIP │   │    1Gi     │   │  │
│  │  └─────────────┘   │static-site   └────────────┘   │  │
│  └─────────────────────────┴──────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Namespace: luismachadoreis-dev   (Production)        │  │
│  │  ┌─────────────┐   ┌──────────┐   ┌────────────┐   │  │
│  │  │ Deployment  │──▶│ Service  │   │ PVC (NFS)  │   │  │
│  │  │ (nginx x3)  │   │ClusterIP │   │    1Gi     │   │  │
│  │  └─────────────┘   │static-site   └────────────┘   │  │
│  └─────────────────────────┴──────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Namespace: carimbo-vip           (Production)        │  │
│  │  ┌─────────────┐   ┌──────────┐   ┌────────────┐   │  │
│  │  │ Deployment  │──▶│ Service  │   │ PVC (NFS)  │   │  │
│  │  │ (nginx x3)  │   │ClusterIP │   │    1Gi     │   │  │
│  │  └─────────────┘   │static-site   └────────────┘   │  │
│  └─────────────────────────┴──────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Namespace: cloudflare-tunnel     (Shared)            │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │ Cloudflare Tunnel (cloudflared x2)              │ │  │
│  │  │ Token-based auth, routes to all domains         │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
terraform/
├── README.md                          ← You are here
├── versions.tf                        ← Terraform & provider versions
├── providers.tf                       ← Kubernetes & Helm provider config
├── variables.tf                       ← Input variables
├── main.tf                            ← Main orchestrator
├── outputs.tf                         ← Output values
├── terraform.tfvars.example           ← Example variables file
├── terraform.tfvars                   ← Your variables (gitignored)
├── domains/                           ← Domain-specific modules
│   ├── README.md                      ← Domain module documentation
│   ├── pudim-dev/                     ← pudim.dev configuration
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── luismachadoreis-dev/           ← luismachadoreis.dev config
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── carimbo-vip/                   ← carimbo.vip configuration
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── modules/                           ← Reusable modules
    ├── nginx-static-site/             ← Generic site module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── cloudflare-tunnel/             ← Shared tunnel module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Prerequisites

1. **Terraform** >= 1.0
   ```bash
   brew install terraform
   ```

2. **kubectl** configured with cluster access
   ```bash
   export KUBECONFIG=~/.kube/config-homelabs
   kubectl get nodes
   ```

3. **Cloudflare Tunnel Token**
   - Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
   - Navigate to: Networks > Tunnels
   - Create a new tunnel or use existing
   - Copy the tunnel token

4. **NFS Storage** (optional but recommended)
   ```bash
   ./scripts/setup-nfs-complete.sh
   ```

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
cloudflare_tunnel_token = "your-actual-token-here"
enable_nfs_storage      = true
storage_class           = "nfs-client"
```

### 3. Plan Changes

```bash
terraform plan
```

Review the planned changes. You should see:
- 4 namespaces (pudim-dev, luismachadoreis-dev, carimbo-vip, cloudflare-tunnel)
- 3 deployments (one per site, 3 replicas each)
- 3 services (ClusterIP, all named "static-site")
- 3 PVCs (if NFS enabled, 1Gi each)
- 1 Cloudflare Tunnel deployment (2 replicas, shared)

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm.

### 5. Verify Deployment

```bash
# Check all site pods
kubectl get pods -A | grep -E "(pudim|luis|carimbo)"

# Check tunnel pods
kubectl get pods -n cloudflare-tunnel

# Check services
kubectl get svc -A | grep static-site

# Check PVCs
kubectl get pvc -A

# Test locally (port-forward)
kubectl port-forward -n pudim-dev svc/static-site 8080:80
# Open http://localhost:8080
```

## Deployed Sites

After deployment, these sites will be available:

| Site | Domain | Namespace | Service Name | Replicas | Environment |
|------|--------|-----------|--------------|----------|-------------|
| Pudim | pudim.dev | pudim-dev | static-site | 3 | Production |
| Luis Machado Reis | luismachadoreis.dev | luismachadoreis-dev | static-site | 3 | Production |
| Carimbo | carimbo.vip | carimbo-vip | static-site | 3 | Production |

**Architecture Notes:**
- Each domain has its own isolated namespace
- All services use the standardized name `static-site` within their namespace
- Cloudflare Tunnel runs in a separate `cloudflare-tunnel` namespace (2 replicas)
- Full DNS name format: `http://static-site.<namespace>.svc.cluster.local:80`

## DNS Configuration

After deployment, configure DNS CNAMEs in Cloudflare:

### For each domain:

1. **pudim.dev**
   ```
   Type: CNAME
   Name: @ (or pudim.dev)
   Content: <your-tunnel-uuid>.cfargotunnel.com
   Proxy: Yes (Orange cloud)
   ```

2. **luismachadoreis.dev**
   ```
   Type: CNAME
   Name: @ (or luismachadoreis.dev)
   Content: <your-tunnel-uuid>.cfargotunnel.com
   Proxy: Yes (Orange cloud)
   ```

3. **carimbo.vip**
   ```
   Type: CNAME
   Name: @ (or carimbo.vip)
   Content: <your-tunnel-uuid>.cfargotunnel.com
   Proxy: Yes (Orange cloud)
   ```

### Get Tunnel UUID

From Cloudflare Dashboard: Zero Trust > Networks > Tunnels > Your Tunnel > Copy UUID

## Updating Site Content

### Method 1: Direct Copy (Quick)

```bash
# Copy files to a running pod
kubectl cp ./my-site/index.html pudim-dev/pudim-dev-xxxxx:/usr/share/nginx/html/

# Or use helper script
./scripts/terraform-helper.sh update-content pudim-dev ./index.html
```

### Method 2: NFS Mount (Recommended)

If using NFS storage, you can update content directly on the master node:

```bash
# SSH to master
ssh root@192.168.5.200

# Navigate to site content (check actual PVC name)
cd /nfs/shared/
ls -la *pudim*
cd pudim-dev-pudim-dev-content-pvc-*/

# Update files
vim index.html

# Changes are immediately visible across all pods
```

### Method 3: Git-based Deployment (Advanced)

Create a CI/CD pipeline that:
1. Builds your static site
2. Creates a ConfigMap or updates NFS content
3. Triggers a pod restart if needed

## Customization

### Add a New Site

1. **Create a new domain module** in `terraform/domains/newsite-com/`:

```bash
mkdir -p terraform/domains/newsite-com
```

2. **Create `domains/newsite-com/main.tf`**:

```hcl
# Create namespace
resource "kubernetes_namespace" "newsite_com" {
  metadata {
    name = "newsite-com"
    labels = {
      name        = "newsite-com"
      domain      = "newsite.com"
      environment = "production"
      managed-by  = "terraform"
    }
  }
}

# Deploy site
module "newsite_com_site" {
  source = "../../modules/nginx-static-site"
  
  site_name    = "newsite-com"
  domain       = "newsite.com"
  namespace    = kubernetes_namespace.newsite_com.metadata[0].name
  environment  = "production"
  replicas     = 3
  enable_nfs   = var.enable_nfs_storage
  storage_class = var.storage_class
  storage_size = "1Gi"
}
```

3. **Update root `main.tf`** to call the new domain module:

```hcl
module "newsite_com" {
  source = "./domains/newsite-com"
  
  enable_nfs_storage = var.enable_nfs_storage
  storage_class      = var.storage_class
}
```

4. **Update Cloudflare Tunnel config** in `modules/cloudflare-tunnel/main.tf`:

```yaml
- hostname: newsite.com
  service: http://static-site.newsite-com.svc.cluster.local:80
```

5. **Apply changes**:

```bash
cd terraform
terraform apply
```

### Adjust Resources

Edit site-specific resource limits in `main.tf`:

```hcl
module "pudim_dev" {
  source = "./modules/nginx-static-site"
  
  # ... other vars ...
  
  resource_limits_cpu      = "200m"
  resource_limits_memory   = "256Mi"
  resource_requests_cpu    = "100m"
  resource_requests_memory = "128Mi"
}
```

### Change Replica Count

```hcl
module "pudim_dev" {
  source = "./modules/nginx-static-site"
  
  replicas = 3  # Increase from 2 to 3
  
  # ... other vars ...
}
```

## Monitoring

### View Logs

```bash
# Site logs
kubectl logs -n pudim-dev -l app=pudim-dev --tail=50 -f

# Tunnel logs
kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel --tail=50 -f

# Or use helper
./scripts/terraform-helper.sh logs pudim-dev
```

### Check Status

```bash
# All sites overview
kubectl get pods -A | grep -E "(pudim|luis|carimbo)"

# Specific namespace
kubectl get all -n pudim-dev

# All deployments
kubectl get deployments -A | grep -E "(pudim|luis|carimbo)"

# All services
kubectl get svc -A | grep static-site

# Or use helper
./scripts/terraform-helper.sh status
```

### Tunnel Metrics

The Cloudflare Tunnel exposes metrics on port 2000:

```bash
kubectl port-forward -n cloudflare-tunnel svc/cloudflare-tunnel-metrics 2000:2000

# Access metrics at http://localhost:2000/metrics
```

## Troubleshooting

### Sites Not Accessible

1. **Check pods are running**:
   ```bash
   kubectl get pods -n pudim-dev
   kubectl get pods -n cloudflare-tunnel
   ```

2. **Check tunnel status**:
   ```bash
   kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel
   ```

3. **Verify DNS**:
   ```bash
   dig pudim.dev
   curl -I https://pudim.dev
   ```

4. **Test internal connectivity**:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl http://static-site.pudim-dev.svc.cluster.local
   ```

### PVC Not Binding

```bash
# Check PVC status (all namespaces)
kubectl get pvc -A

# Describe specific PVC
kubectl describe pvc pudim-dev-content -n pudim-dev

# Check StorageClass
kubectl get storageclass nfs-client

# Check NFS provisioner
kubectl get pods -n nfs-system
```

### Terraform State Issues

```bash
# Refresh state
terraform refresh

# Show state
terraform show

# List resources
terraform state list

# Import existing resource (if needed)
terraform import module.pudim_dev.kubernetes_namespace.pudim_dev pudim-dev
```

## Maintenance

### Update Nginx Image

Edit `domains/pudim-dev/main.tf`:

```hcl
module "pudim_dev_site" {
  source = "../../modules/nginx-static-site"
  
  nginx_image = "nginx:1.25-alpine"  # Specify version
  
  # ... other vars ...
}
```

Apply:
```bash
cd terraform
terraform apply
```

### Backup Content

If using NFS:
```bash
ssh root@192.168.5.200 'tar -czf /tmp/static-sites-backup.tar.gz /nfs/shared/static-sites-*'
scp root@192.168.5.200:/tmp/static-sites-backup.tar.gz ./backups/
```

### Destroy Everything

⚠️ **Warning**: This will delete all sites and content!

```bash
terraform destroy
```

Or use helper:
```bash
./scripts/terraform-helper.sh destroy
```

## Terraform Commands Reference

```bash
# Initialize
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output

# Show current state
terraform show

# Refresh state
terraform refresh

# Destroy resources
terraform destroy

# List resources in state
terraform state list

# Show specific resource
terraform state show kubernetes_deployment.pudim_dev
```

## Helper Script

A helper script is available for common operations:

```bash
# Show help
./scripts/terraform-helper.sh help

# Initialize
./scripts/terraform-helper.sh init

# Plan
./scripts/terraform-helper.sh plan

# Apply
./scripts/terraform-helper.sh apply

# Show status
./scripts/terraform-helper.sh status

# List sites
./scripts/terraform-helper.sh list-sites

# Update content
./scripts/terraform-helper.sh update-content pudim-dev ./index.html

# Show logs
./scripts/terraform-helper.sh logs pudim-dev
```

## Security

### Sensitive Data

- `terraform.tfvars` is gitignored (contains tunnel token)
- Tunnel token is stored as a Kubernetes Secret
- Never commit `terraform.tfstate` (contains sensitive data)

### Best Practices

1. **Use remote state** for team collaboration:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "my-terraform-state"
       key    = "homelabs/terraform.tfstate"
       region = "us-east-1"
     }
   }
   ```

2. **Rotate tunnel tokens** periodically

3. **Use RBAC** to limit access to namespaces

4. **Enable Pod Security Policies**

## Cost Optimization

### Resource Requests

Current configuration uses minimal resources:
- CPU: 50m per container
- Memory: 64Mi per container

For production, consider:
- Horizontal Pod Autoscaling (HPA)
- Vertical Pod Autoscaling (VPA)
- Resource quotas per namespace

### Storage

- NFS storage is shared and cost-effective
- Each site gets 1Gi by default
- Adjust as needed based on content size

## Next Steps

1. ✅ Deploy infrastructure with Terraform
2. ✅ Configure DNS CNAMEs
3. 📝 Upload your site content
4. 🔒 Add SSL/TLS (handled by Cloudflare)
5. 📊 Set up monitoring (Grafana dashboards)
6. 🚀 Deploy more sites as needed

## Support

For issues or questions:
- Check logs: `kubectl logs -n static-sites <pod-name>`
- Review Terraform output: `terraform output`
- Consult documentation: `docs/`

---

**Managed by Terraform** | **Version**: 1.0 | **Last Updated**: Nov 2025

