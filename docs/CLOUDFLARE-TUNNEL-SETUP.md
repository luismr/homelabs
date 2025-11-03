# Cloudflare Tunnel Setup Guide

## Overview

Cloudflare Tunnel provides a secure way to expose your Kubernetes services to the internet without opening firewall ports or requiring a public IP address.

### How It Works

```
Internet User
     ↓
Cloudflare Network (DDoS protection, CDN, SSL)
     ↓
Cloudflare Tunnel (encrypted connection)
     ↓
Your Kubernetes Cluster (cloudflared pod)
     ↓
Your Services (nginx sites)
```

## Prerequisites

1. **Cloudflare Account** (free tier works)
2. **Domain(s) added to Cloudflare**
3. **Kubernetes cluster** running
4. **kubectl** access to the cluster

## Step-by-Step Setup

### 1. Create Cloudflare Tunnel

#### Option A: Using Cloudflare Dashboard (Recommended)

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)

2. Navigate to **Networks** > **Tunnels**

3. Click **Create a tunnel**

4. Choose **Cloudflared**

5. Name your tunnel (e.g., `homelabs-k3s`)

6. Click **Save tunnel**

7. **Copy the tunnel token** - you'll need this!
   ```
   Format: eyJhIjoiXXXXXXX...
   ```

8. Click **Next** (don't install connector yet - Terraform will do this)

9. Configure **Public Hostnames** (Optional - config.yaml handles this):
   - **pudim.dev**
     - Subdomain: *(leave empty)*
     - Domain: pudim.dev
     - Service: http://static-site.pudim-dev.svc.cluster.local:80
   
   - **luismachadoreis.dev**
     - Subdomain: *(leave empty)*
     - Domain: luismachadoreis.dev
     - Service: http://static-site.luismachadoreis-dev.svc.cluster.local:80
   
   - **carimbo.vip**
     - Subdomain: *(leave empty)*
     - Domain: carimbo.vip
     - Service: http://static-site.carimbo-vip.svc.cluster.local:80
   
   **Note**: With token-based tunnels, the ingress rules in config.yaml automatically configure these hostnames.

10. Click **Save tunnel**

#### Option B: Using CLI

```bash
# Install cloudflared
brew install cloudflare/cloudflare/cloudflared

# Login
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create homelabs-k3s

# Get tunnel info
cloudflared tunnel list

# Get tunnel token
cloudflared tunnel token homelabs-k3s
```

### 2. Configure Terraform

Create or edit `terraform/terraform.tfvars`:

```hcl
cloudflare_tunnel_token = "eyJhIjoiXXXXXXX..."  # Your actual token
enable_nfs_storage      = true
storage_class           = "nfs-client"
```

### 3. Deploy with Terraform

```bash
cd terraform

# Initialize (if not done)
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### 4. Verify Tunnel is Running

```bash
export KUBECONFIG=~/.kube/config-homelabs

# Check tunnel pods
kubectl get pods -n cloudflare-tunnel

# Check logs
kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel
```

You should see output like:
```
Registered tunnel connection connIndex=0
Registered tunnel connection connIndex=1
```

### 5. Configure DNS

For each domain, add a CNAME record in Cloudflare DNS:

#### Get Tunnel CNAME Target

From the Cloudflare Dashboard:
- Go to **Zero Trust** > **Networks** > **Tunnels**
- Click your tunnel name
- Copy the **Tunnel UUID** (something like `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
- The CNAME target is: `{tunnel-uuid}.cfargotunnel.com`

#### Add DNS Records

1. **pudim.dev**
   - Type: `CNAME`
   - Name: `@` (or `pudim.dev`)
   - Target: `{tunnel-uuid}.cfargotunnel.com`
   - Proxy status: **Proxied** (orange cloud)
   - TTL: Auto

2. **www.pudim.dev** (optional)
   - Type: `CNAME`
   - Name: `www`
   - Target: `{tunnel-uuid}.cfargotunnel.com`
   - Proxy status: **Proxied**

3. Repeat for **luismachadoreis.dev** and **carimbo.vip**

### 6. Test Your Sites

Wait 1-2 minutes for DNS propagation, then:

```bash
curl -I https://pudim.dev
curl -I https://luismachadoreis.dev
curl -I https://carimbo.vip
```

Or visit in a browser:
- https://pudim.dev
- https://luismachadoreis.dev
- https://carimbo.vip

## Tunnel Configuration

### Default Configuration

The tunnel is configured to route traffic based on hostname. Each domain has its own namespace with a standardized service name (`static-site`):

```yaml
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
```

**Key Architecture Points:**
- Each domain has its own Kubernetes namespace for isolation
- All sites use the standardized service name `static-site` within their namespace
- Cloudflare Tunnel runs in its own `cloudflare-tunnel` namespace
- Tunnel uses token-based authentication (no certificate files needed)

### Add More Hostnames

1. Create a new domain module in `terraform/domains/newsite-com/`
2. Add the module call in `terraform/main.tf`
3. Edit `terraform/modules/cloudflare-tunnel/main.tf` and add to the ingress rules:

```yaml
- hostname: newsite.com
  service: http://static-site.newsite-com.svc.cluster.local:80
```

Then apply:
```bash
cd terraform
terraform apply
```

## Monitoring

### Check Tunnel Status

```bash
# Pod status
kubectl get pods -n cloudflare-tunnel

# Logs
kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel -f

# Metrics endpoint
kubectl port-forward -n cloudflare-tunnel svc/cloudflare-tunnel-metrics 2000:2000
# Visit http://localhost:2000/metrics
```

### Cloudflare Dashboard

View tunnel metrics and traffic in the Cloudflare Dashboard:
- **Zero Trust** > **Networks** > **Tunnels** > Your tunnel
- Shows connection status, traffic, requests

### Prometheus Integration

The tunnel exposes metrics on port 2000. Create a ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cloudflare-tunnel
  namespace: cloudflare-tunnel
spec:
  selector:
    matchLabels:
      app: cloudflare-tunnel
  endpoints:
  - port: metrics
    interval: 30s
```

## Troubleshooting

### Tunnel Not Connecting

**Check tunnel token**:
```bash
kubectl get secret -n cloudflare-tunnel cloudflare-tunnel-token -o jsonpath='{.data.token}' | base64 -d
```

**Check logs**:
```bash
kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel
```

Look for errors like:
- `Authentication error`: Invalid token
- `Connection refused`: Service not reachable  
- `Cannot determine default origin certificate path`: This is a warning and can be ignored when using token-based auth

**Verify services are running**:
```bash
kubectl get svc -A | grep static-site
kubectl get endpoints -A | grep static-site
```

### Sites Not Accessible

1. **Check DNS**:
   ```bash
   dig pudim.dev
   nslookup pudim.dev
   ```

2. **Check Cloudflare SSL/TLS settings**:
   - Go to **SSL/TLS** in Cloudflare Dashboard
   - Set to **Flexible** or **Full**
   - NOT "Full (strict)" (unless you have valid certs in cluster)

3. **Test internal connectivity**:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v http://static-site.pudim-dev.svc.cluster.local
   ```

4. **Check tunnel configuration**:
   ```bash
   kubectl get configmap -n cloudflare-tunnel cloudflare-tunnel-config -o yaml
   ```

### DNS Not Resolving

- **Wait 5 minutes** for DNS propagation
- **Clear DNS cache**:
  ```bash
  # macOS
  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
  
  # Linux
  sudo systemd-resolve --flush-caches
  ```
- **Use different DNS server**: Try 1.1.1.1 (Cloudflare DNS)

### 502 Bad Gateway

This usually means the service is unreachable:

```bash
# Check if pods are running
kubectl get pods -n pudim-dev

# Check if services have endpoints
kubectl get endpoints -n pudim-dev

# Restart deployment
kubectl rollout restart deployment/pudim-dev -n pudim-dev
```

## Security

### Best Practices

1. **Keep tunnel token secret**
   - Never commit to git
   - Store in secure password manager
   - Rotate periodically

2. **Use Cloudflare WAF** (Web Application Firewall)
   - Enable in Cloudflare Dashboard
   - Create custom rules for protection

3. **Enable Rate Limiting**
   - Protect against DDoS
   - Configure in Cloudflare Dashboard

4. **Monitor Access Logs**
   - Review in Cloudflare Analytics
   - Set up alerts for suspicious activity

### Rotating Tunnel Token

1. **Create new tunnel** in Cloudflare Dashboard
2. **Get new token**
3. **Update terraform.tfvars**:
   ```hcl
   cloudflare_tunnel_token = "new-token-here"
   ```
4. **Apply changes**:
   ```bash
   terraform apply
   ```
5. **Verify new tunnel is working**
6. **Delete old tunnel** in Cloudflare Dashboard

## Advanced Configuration

### Custom Headers

Add custom headers in tunnel configuration:

```yaml
ingress:
  - hostname: pudim.dev
    service: http://static-site.pudim-dev.svc.cluster.local:80
    originRequest:
      httpHostHeader: pudim.dev
      noTLSVerify: false
```

### HTTP/2 Support

Enabled by default. Ensure your nginx is configured for HTTP/2:

```nginx
server {
    listen 80 http2;
    # ...
}
```

### Load Balancing

Run multiple tunnel replicas (already configured):

```hcl
module "cloudflare_tunnel" {
  # ...
  replicas = 3  # Increase for more reliability
}
```

## Cost

### Cloudflare Tunnel Pricing

- **Free Tier**: Unlimited bandwidth, perfect for personal projects
- **Zero Trust Free**: Includes Cloudflare Tunnel
- **No egress fees**: Unlike cloud load balancers

### Resource Usage

Current configuration per tunnel replica:
- CPU: 100m (0.1 core)
- Memory: 128Mi
- Total for 2 replicas: 0.2 cores, 256Mi

## Alternative: Without Cloudflare Tunnel

If you don't want to use Cloudflare Tunnel, you can:

### Option 1: NodePort

Change service type to NodePort:

```hcl
# In nginx-static-site module
spec {
  type = "NodePort"
  port {
    port       = 80
    node_port  = 30080  # Choose unique port
  }
}
```

Access at: `http://<node-ip>:30080`

### Option 2: Ingress Controller

Deploy an Ingress controller (e.g., Traefik, Nginx Ingress):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

Create Ingress resources for your sites.

### Option 3: Port Forwarding

For development only:

```bash
kubectl port-forward -n static-sites svc/pudim-dev 8080:80
```

Access at: `http://localhost:8080`

## Summary

### Quick Reference

```bash
# Check tunnel status
kubectl get pods -n cloudflare-tunnel

# View logs
kubectl logs -n cloudflare-tunnel -l app=cloudflare-tunnel -f

# Restart tunnel
kubectl rollout restart deployment/cloudflare-tunnel -n cloudflare-tunnel

# Update configuration
# Edit terraform/modules/cloudflare-tunnel/main.tf
cd terraform && terraform apply

# Test connectivity
curl -I https://pudim.dev
curl -I https://luismachadoreis.dev
curl -I https://carimbo.vip
```

### URLs

- **Cloudflare Dashboard**: https://dash.cloudflare.com/
- **Zero Trust Dashboard**: https://one.dash.cloudflare.com/
- **Tunnel Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

---

**Managed by Terraform** | **Last Updated**: Nov 2025

