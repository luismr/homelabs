# Homelabs 4-Node Debian Cluster

A Vagrant-managed 4-node Debian Bookworm cluster with bridged networking on a /22 subnet.

## Cluster Configuration

| Node    | IP Address      | CPU | RAM  | SSH Port |
|---------|-----------------|-----|------|----------|
| master  | 192.168.5.200   | 2   | 4GB  | 22       |
| worker1 | 192.168.5.201   | 2   | 4GB  | 22       |
| worker2 | 192.168.5.202   | 2   | 4GB  | 22       |
| worker3 | 192.168.5.203   | 2   | 4GB  | 22       |

**Network**: 192.168.4.0/22 (255.255.252.0)  
**Gateway**: 192.168.4.1  
**DNS**: 8.8.8.8, 8.8.4.4  
**Bridge Interface**: en2: Wi-Fi (AirPort)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                  │
│                              ↓                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │              Cloudflare Network (Global CDN)               │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │   │
│  │  │  pudim.dev   │  │luismachado   │  │ carimbo.vip  │    │   │
│  │  │   (DNS)      │  │ reis.dev     │  │   (DNS)      │    │   │
│  │  │   CNAME ──────────▶ CNAME ────────────▶ CNAME     │    │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │   │
│  │           │                 │                 │            │   │
│  │           └─────────────────┼─────────────────┘            │   │
│  │                             ▼                              │   │
│  │              ┌──────────────────────────┐                  │   │
│  │              │  Cloudflare Tunnel       │                  │   │
│  │              │  (Encrypted Connection)  │                  │   │
│  │              └──────────────┬───────────┘                  │   │
│  └─────────────────────────────┼──────────────────────────────┘   │
└────────────────────────────────┼──────────────────────────────────┘
                                 │ Token Auth
                                 │ HTTPS/QUIC
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (k3s)                         │
│                    192.168.5.200-203 (/22 subnet)                   │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ Namespace: cloudflare-tunnel                              │    │
│  │  ┌────────────────────────────────────────────────────┐   │    │
│  │  │ cloudflared pods (x2 replicas)                     │   │    │
│  │  │ Routes traffic based on hostname                   │   │    │
│  │  └─────┬──────────────┬──────────────┬─────────────────   │    │
│  └────────┼──────────────┼──────────────┼────────────────────┘    │
│           │              │              │                          │
│           ▼              ▼              ▼                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                  │
│  │Namespace:  │  │Namespace:  │  │Namespace:  │                  │
│  │pudim-dev   │  │luismachado │  │carimbo-vip │                  │
│  │            │  │  reis-dev  │  │            │                  │
│  │ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │                  │
│  │ │Service │ │  │ │Service │ │  │ │Service │ │                  │
│  │ │ static │ │  │ │ static │ │  │ │ static │ │                  │
│  │ │ -site  │ │  │ │ -site  │ │  │ │ -site  │ │                  │
│  │ │ClusterIP│ │  │ │ClusterIP│ │  │ │ClusterIP│ │                  │
│  │ └───┬────┘ │  │ └───┬────┘ │  │ └───┬────┘ │                  │
│  │     │      │  │     │      │  │     │      │                  │
│  │ ┌───▼────┐ │  │ ┌───▼────┐ │  │ ┌───▼────┐ │                  │
│  │ │Nginx   │ │  │ │Nginx   │ │  │ │Nginx   │ │                  │
│  │ │Pods x3 │ │  │ │Pods x3 │ │  │ │Pods x3 │ │                  │
│  │ └───┬────┘ │  │ └───┬────┘ │  │ └───┬────┘ │                  │
│  │     │      │  │     │      │  │     │      │                  │
│  │ ┌───▼────┐ │  │ ┌───▼────┐ │  │ ┌───▼────┐ │                  │
│  │ │PVC     │ │  │ │PVC     │ │  │ │PVC     │ │                  │
│  │ │(NFS)   │ │  │ │(NFS)   │ │  │ │(NFS)   │ │                  │
│  │ │1Gi     │ │  │ │1Gi     │ │  │ │1Gi     │ │                  │
│  │ └───┬────┘ │  │ └───┬────┘ │  │ └───┬────┘ │                  │
│  └─────┼──────┘  └─────┼──────┘  └─────┼──────┘                  │
│        │                │                │                         │
│        └────────────────┼────────────────┘                         │
│                         ▼                                          │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │          NFS Server (Master Node: 192.168.5.200)            │  │
│  │          Shared Storage: /nfs/shared/                       │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ Namespace: monitoring                                       │  │
│  │  Prometheus | Grafana | Loki | Alertmanager | Promtail     │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

Legend:
→  HTTP/HTTPS Traffic Flow
┌─ Kubernetes Namespace Boundary
│  Service/Pod/Resource
```

**Traffic Flow:**
1. User requests `pudim.dev`, `luismachadoreis.dev`, or `carimbo.vip`
2. DNS resolves to Cloudflare's network (CNAME → tunnel UUID)
3. Cloudflare routes to your Cloudflare Tunnel (encrypted, token-authenticated)
4. Tunnel pods inspect hostname and route to appropriate namespace service
5. Service load-balances across 3 nginx pod replicas
6. Nginx serves static content from NFS-backed persistent storage

## Project Structure

```
homelabs/
├── README.md                    ← You are here
├── Vagrantfile                  ← VM configuration
├── docs/                        ← Documentation
│   ├── CLUSTER-INFO.md         ← Quick reference & access info
│   ├── SETUP-GUIDE.md          ← Complete setup tutorial
│   ├── LOKI-GUIDE.md           ← Log collection guide
│   ├── NFS-STORAGE-GUIDE.md    ← NFS shared storage guide
│   ├── GIT-QUICK-REFERENCE.md  ← Git commands reference
│   └── .gitignore-README.md    ← .gitignore guide
├── scripts/                     ← Installation & helper scripts
│   ├── setup-cluster.sh         ← Automated cluster setup
│   ├── install-k3s-master.sh    ← Master node installation
│   ├── install-k3s-worker.sh    ← Worker node installation
│   ├── install-observability.sh ← Monitoring stack installation
│   ├── setup-nfs-complete.sh    ← Complete NFS setup
│   ├── setup-nfs-server.sh      ← NFS server setup
│   ├── setup-nfs-clients.sh     ← NFS client setup
│   ├── deploy-nfs-provisioner.sh ← NFS CSI provisioner
│   ├── verify-cluster.sh        ← Cluster health check
│   └── ssh-nodes.sh             ← SSH helper
└── examples/                    ← Example manifests
    ├── nfs-test-deployment.yaml ← NFS test example
    ├── nfs-nginx-deployment.yaml ← Nginx with NFS
    └── nfs-statefulset.yaml     ← StatefulSet with NFS
```

## Quick Start

### Vagrant Commands

```bash
# Start all nodes
vagrant up

# Stop all nodes
vagrant halt

# Restart all nodes
vagrant reload

# Check status
vagrant status

# Destroy cluster
vagrant destroy -f

# Re-provision (apply configuration changes)
vagrant provision
```

### SSH Access

Your SSH public key has been installed on all nodes for both `vagrant` and `root` users.

#### Direct SSH Access

```bash
# SSH as vagrant user
ssh vagrant@192.168.5.200  # master
ssh vagrant@192.168.5.201  # worker1
ssh vagrant@192.168.5.202  # worker2
ssh vagrant@192.168.5.203  # worker3

# SSH as root
ssh root@192.168.5.200     # master (root)
ssh root@192.168.5.201     # worker1 (root)
```

#### Using the Helper Script

```bash
# Quick access using the helper script
./scripts/ssh-nodes.sh master   # or: ./scripts/ssh-nodes.sh m
./scripts/ssh-nodes.sh worker1  # or: ./scripts/ssh-nodes.sh w1
./scripts/ssh-nodes.sh worker2  # or: ./scripts/ssh-nodes.sh w2
./scripts/ssh-nodes.sh worker3  # or: ./scripts/ssh-nodes.sh w3
```

#### Via Vagrant

```bash
vagrant ssh master
vagrant ssh worker1
vagrant ssh worker2
vagrant ssh worker3
```

## Features

- ✅ Debian Bookworm 64-bit
- ✅ Bridged networking with static IPs
- ✅ Kubernetes-ready configuration:
  - Swap disabled
  - IP forwarding enabled
  - Bridge netfilter enabled
  - br_netfilter module loaded
- ✅ SSH key authentication enabled
- ✅ Essential tools installed: curl, jq, net-tools, gnupg
- ✅ Custom DNS configuration
- ✅ Promiscuous mode enabled for networking
- ✅ NFS shared storage (master node as NFS server)
  - Dynamic volume provisioning
  - ReadWriteMany support
  - Persistent storage for applications

## Documentation

- **[SETUP-GUIDE.md](docs/SETUP-GUIDE.md)** - Complete step-by-step setup tutorial (1,446 lines)
- **[CLUSTER-INFO.md](docs/CLUSTER-INFO.md)** - Quick reference and access information
- **[LOKI-GUIDE.md](docs/LOKI-GUIDE.md)** - Log collection and querying guide
- **[NFS-STORAGE-GUIDE.md](docs/NFS-STORAGE-GUIDE.md)** - Shared persistent storage guide
- **[CLOUDFLARE-TUNNEL-SETUP.md](docs/CLOUDFLARE-TUNNEL-SETUP.md)** - Cloudflare Tunnel configuration guide
- **[GIT-QUICK-REFERENCE.md](docs/GIT-QUICK-REFERENCE.md)** - Git commands reference
- **[.gitignore-README.md](docs/.gitignore-README.md)** - .gitignore guide and best practices
- **[terraform/README.md](terraform/README.md)** - Terraform infrastructure documentation

## Testing Connectivity

```bash
# Ping all nodes
for ip in 192.168.5.{200..203}; do ping -c 1 $ip; done

# Run command on all nodes
for ip in 192.168.5.{200..203}; do 
  ssh vagrant@$ip "hostname && uptime"
done
```

## k3s Cluster with Observability

### Quick Setup

Run the automated setup script to install k3s with full observability:

```bash
./scripts/setup-cluster.sh
```

This will:
1. Install k3s on the master node (192.168.5.200)
2. Join all 3 worker nodes to the cluster
3. Set up kubectl access on your local machine
4. Install Prometheus, Grafana, and Loki for observability

### Manual Installation

If you prefer manual control:

```bash
# 1. Install k3s master
ssh root@192.168.5.200 < scripts/install-k3s-master.sh

# 2. Get the node token
NODE_TOKEN=$(ssh root@192.168.5.200 'cat /var/lib/rancher/k3s/server/node-token')

# 3. Install workers
ssh root@192.168.5.201 "bash -s -- 192.168.5.200 $NODE_TOKEN" < scripts/install-k3s-worker.sh
ssh root@192.168.5.202 "bash -s -- 192.168.5.200 $NODE_TOKEN" < scripts/install-k3s-worker.sh
ssh root@192.168.5.203 "bash -s -- 192.168.5.200 $NODE_TOKEN" < scripts/install-k3s-worker.sh

# 4. Copy kubeconfig
ssh root@192.168.5.200 'cat /etc/rancher/k3s/k3s.yaml' | \
  sed "s/127.0.0.1/192.168.5.200/g" > ~/.kube/config-homelabs
export KUBECONFIG=~/.kube/config-homelabs

# 5. Install observability stack
scp scripts/install-observability.sh root@192.168.5.200:/tmp/
ssh root@192.168.5.200 'bash /tmp/install-observability.sh'
```

### Observability Stack

**Included Components:**
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Alertmanager**: Alert management
- **Node Exporter**: Host-level metrics
- **Promtail**: Log collection agent

**Access URLs:**
- **Grafana**: http://192.168.5.200:30080
  - Username: `admin`
  - Password: `admin`
- **Prometheus**: http://192.168.5.200:30090
- **Alertmanager**: http://192.168.5.200:30093

**Pre-configured Dashboards:**
- Kubernetes Cluster Overview
- Namespace Resources
- Node Resources
- Pod Resources
- Node Exporter Metrics

### kubectl Commands

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-homelabs

# View cluster nodes
kubectl get nodes -o wide

# View all pods
kubectl get pods -A

# View monitoring stack
kubectl get all -n monitoring

# Access Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f
```

## NFS Shared Storage

The master node provides NFS shared storage for persistent volumes across all worker nodes.

### Setup NFS

```bash
# Automated setup (recommended)
./scripts/setup-nfs-complete.sh
```

This will:
1. Configure master node as NFS server
2. Install NFS clients on all workers
3. Deploy NFS CSI driver for dynamic provisioning
4. Create StorageClasses for your applications

### Using NFS Storage

Create a PersistentVolumeClaim:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-storage
spec:
  accessModes:
    - ReadWriteMany  # Shared access across pods
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs-client  # Default NFS storage
```

### Test NFS

```bash
# Deploy test pods
kubectl apply -f examples/nfs-test-deployment.yaml

# Check if data is shared
kubectl logs nfs-writer
kubectl logs nfs-reader

# Cleanup
kubectl delete -f examples/nfs-test-deployment.yaml
```

### Available Storage Classes

- **nfs-client** (default) - General purpose shared storage
- **nfs-grafana** - Reserved for Grafana (if needed)
- **nfs-prometheus** - Reserved for Prometheus (if needed)
- **nfs-loki** - Reserved for Loki (if needed)

See **[NFS-STORAGE-GUIDE.md](docs/NFS-STORAGE-GUIDE.md)** for complete documentation.

## Terraform Infrastructure

Manage Kubernetes deployments declaratively with Terraform.

### Deployed Static Sites

Three nginx-based static websites managed by Terraform, each in its own namespace:

```bash
# View deployment status
cd terraform
terraform output

# Sites (Production - 3 replicas each):
- pudim.dev           → pudim-dev namespace
- luismachadoreis.dev → luismachadoreis-dev namespace  
- carimbo.vip         → carimbo-vip namespace
```

### Quick Commands

```bash
# Check all deployments
kubectl get pods -A | grep -E "(pudim|luis|carimbo)"

# View specific site
kubectl get all -n pudim-dev

# Update site content (via NFS)
ssh root@192.168.5.200
cd /nfs/shared/
ls -la *pudim*
# Edit your HTML files

# Or use helper script
./scripts/terraform-helper.sh status
```

### Adding Cloudflare Tunnel

To expose sites publicly:

1. Get tunnel token from [Cloudflare Dashboard](https://one.dash.cloudflare.com/)
2. Update `terraform/terraform.tfvars`:
   ```hcl
   cloudflare_tunnel_token = "your-token-here"
   ```
3. Apply changes:
   ```bash
   cd terraform
   terraform apply
   ```

See **[CLOUDFLARE-TUNNEL-SETUP.md](docs/CLOUDFLARE-TUNNEL-SETUP.md)** and **[terraform/README.md](terraform/README.md)** for detailed guides.

## Next Steps

This cluster is now ready for:
- Deploying containerized applications
- Testing distributed systems
- Running CI/CD pipelines
- Database clustering (PostgreSQL, MongoDB, etc.)
- Service mesh experimentation (Istio, Linkerd)

## Troubleshooting

### VM not reachable
```bash
# Check VM is running
vagrant status

# Check IP configuration
vagrant ssh master -c "ip addr show"

# Restart networking
vagrant reload master
```

### SSH connection refused
```bash
# Check SSH service
vagrant ssh master -c "sudo systemctl status ssh"

# Verify authorized keys
vagrant ssh master -c "cat ~/.ssh/authorized_keys"
```

### Performance issues
```bash
# Adjust VM resources in Vagrantfile
# Modify cpu and ram values in NODES array
```

## Plugin Requirements

- **VirtualBox**: Required
- **Vagrant**: Required
- **vagrant-disksize**: Optional (for 32GB disks)

```bash
vagrant plugin install vagrant-disksize
```

