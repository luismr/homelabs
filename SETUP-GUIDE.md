# Complete Homelab Setup Guide
## 4-Node k3s Cluster with Full Observability Stack

**Time to Complete**: ~30-45 minutes  
**Difficulty**: Intermediate  
**Cost**: Free (all open-source tools)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Step 1: Install Required Software](#step-1-install-required-software)
4. [Step 2: Create Project Directory](#step-2-create-project-directory)
5. [Step 3: Configure Vagrant](#step-3-configure-vagrant)
6. [Step 4: Launch Virtual Machines](#step-4-launch-virtual-machines)
7. [Step 5: Configure SSH Access](#step-5-configure-ssh-access)
8. [Step 6: Install k3s Cluster](#step-6-install-k3s-cluster)
9. [Step 7: Install Observability Stack](#step-7-install-observability-stack)
10. [Step 8: Verify Installation](#step-8-verify-installation)
11. [Step 9: Explore Grafana Dashboards](#step-9-explore-grafana-dashboards)
12. [Step 10: Deploy Sample Application](#step-10-deploy-sample-application)
13. [Troubleshooting](#troubleshooting)
14. [Daily Operations](#daily-operations)
15. [Cleanup and Maintenance](#cleanup-and-maintenance)

---

## Prerequisites

### Hardware Requirements

- **CPU**: Multi-core processor (4+ cores recommended)
- **RAM**: Minimum 16GB (20GB+ recommended)
- **Disk**: 50GB+ free space
- **Network**: Active network connection for VM bridging

### Software Requirements

- **Host OS**: macOS, Linux, or Windows
- **VirtualBox**: 7.0 or later
- **Vagrant**: 2.0 or later
- **SSH**: OpenSSH client (pre-installed on macOS/Linux)

### Network Requirements

- Access to a /22 network (192.168.4.0/22 in this guide)
- Your host machine should be on this network
- No firewall blocking ports: 22, 80, 443, 6443, 30080, 30090, 30093

### Knowledge Requirements

- Basic command-line skills
- Understanding of SSH
- Familiarity with YAML (helpful but not required)
- Basic Kubernetes concepts (helpful but not required)

---

## Architecture Overview

### Cluster Design

```
                    ┌─────────────────────────────────────┐
                    │     Your Host Machine (Mac/PC)      │
                    │  - kubectl configured               │
                    │  - SSH access to all nodes          │
                    │  - Browser access to dashboards     │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │  192.168.4.0/22 Network     │
                    │  (Bridged Networking)        │
                    └──────────────┬──────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
┌───────▼────────┐    ┌───────────▼─────┐    ┌──────────────▼──────┐
│  Master Node   │    │  Worker Node 1   │    │  Worker Nodes 2 & 3 │
│ 192.168.5.200  │    │ 192.168.5.201    │    │ 192.168.5.202-203   │
│                │    │                  │    │                     │
│ - k3s server   │    │ - k3s agent      │    │ - k3s agent         │
│ - etcd         │    │ - Workloads      │    │ - Workloads         │
│ - API server   │    │                  │    │                     │
│ - Monitoring   │    │                  │    │                     │
│   Stack:       │    │                  │    │                     │
│   • Prometheus │    │                  │    │                     │
│   • Grafana    │    │                  │    │                     │
│   • Loki       │    │                  │    │                     │
│                │    │                  │    │                     │
│ 2 CPU / 4GB    │    │ 2 CPU / 4GB      │    │ 2 CPU / 4GB each    │
└────────────────┘    └──────────────────┘    └─────────────────────┘
```

### Components

| Component | Purpose | Port |
|-----------|---------|------|
| **k3s** | Lightweight Kubernetes distribution | 6443 |
| **Prometheus** | Metrics collection and storage | 30090 |
| **Grafana** | Visualization and dashboards | 30080 |
| **Loki** | Log aggregation | 3100 |
| **Alertmanager** | Alert management | 30093 |
| **Node Exporter** | Host metrics | 9100 |
| **Promtail** | Log collection agent | 9080 |

### Network Configuration

- **Subnet**: 192.168.4.0/22 (255.255.252.0)
- **Gateway**: 192.168.4.1
- **DNS**: 8.8.8.8, 8.8.4.4
- **IP Range**: 192.168.4.0 - 192.168.7.255 (1024 addresses)

---

## Step 1: Install Required Software

### macOS

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install VirtualBox
brew install --cask virtualbox

# Install Vagrant
brew install --cask vagrant

# Install vagrant-disksize plugin (optional, for larger disks)
vagrant plugin install vagrant-disksize

# Verify installations
virtualbox --help
vagrant --version
```

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# Install VirtualBox
sudo apt install -y virtualbox virtualbox-ext-pack

# Install Vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant

# Install vagrant-disksize plugin
vagrant plugin install vagrant-disksize

# Verify installations
vboxmanage --version
vagrant --version
```

### Windows

1. Download and install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
2. Download and install [Vagrant](https://www.vagrantup.com/downloads)
3. Open PowerShell as Administrator and run:
   ```powershell
   vagrant plugin install vagrant-disksize
   ```

---

## Step 2: Create Project Directory

```bash
# Create project directory
mkdir -p ~/homelabs
cd ~/homelabs

# Create a README placeholder
echo "# Homelabs k3s Cluster" > README.md

# Verify you're in the right directory
pwd
```

**Expected Output**: `/Users/yourusername/homelabs` (or similar)

---

## Step 3: Configure Vagrant

### 3.1: Create Vagrantfile

Create a file named `Vagrantfile` in your project directory:

```bash
cd ~/homelabs
nano Vagrantfile  # or use your preferred editor
```

**Copy and paste this content**:

```ruby
# Homelabs 4-node Debian cluster (bridged, /22)
# Requires: VirtualBox, Vagrant
# Optional: vagrant-disksize plugin for 32GB disks:
#   vagrant plugin install vagrant-disksize

NETMASK  = "255.255.252.0"  # /22 (192.168.4.0–192.168.7.255)
GATEWAY  = "192.168.4.1"
DNS      = ["8.8.8.8", "8.8.4.4"]

NODES = [
  {name: "master",  ip: "192.168.5.200", cpu: 2, ram: 4096},
  {name: "worker1", ip: "192.168.5.201", cpu: 2, ram: 4096},
  {name: "worker2", ip: "192.168.5.202", cpu: 2, ram: 4096},
  {name: "worker3", ip: "192.168.5.203", cpu: 2, ram: 4096},
]

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Make sure vbguest (if present) doesn't interfere
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
    config.vbguest.no_remote = true
  end

  NODES.each do |node|
    config.vm.define node[:name] do |vm|
      vm.vm.hostname = node[:name]

      # Bridged NIC with static IP on /22
      vm.vm.network :public_network,
        ip: node[:ip],
        netmask: NETMASK
        # Uncomment and modify if you want to specify a bridge:
        # bridge: "en0: Wi-Fi (AirPort)"

      vm.vm.provider :virtualbox do |vb|
        vb.name   = "hlab-#{node[:name]}"
        vb.cpus   = node[:cpu]
        vb.memory = node[:ram]
        vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
      end

      # 32 GB disk via plugin (comment if you don't use the plugin)
      if Vagrant.has_plugin?("vagrant-disksize")
        vm.disksize.size = "32GB"
      end

      vm.vm.provision "shell", privileged: true, inline: <<-SHELL
        set -euo pipefail
        apt-get update -y
        apt-get install -y curl ca-certificates gnupg lsb-release jq net-tools iproute2

        # K8s-friendly sysctls (safe even if you don't install k3s yet)
        swapoff -a || true
        sed -i.bak '/ swap / s/^/#/' /etc/fstab || true
        modprobe br_netfilter || true
        sysctl -w net.ipv4.ip_forward=1
        echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-ipforward.conf
        echo 'net.bridge.bridge-nf-call-iptables=1' > /etc/sysctl.d/99-k8s.conf
        sysctl --system

        # Make bridged NIC the default route (optional but recommended here)
        IFACE=$(ip -o -4 addr show | awk '/192\\.168\\.(4|5|6|7)\\./ {print $2; exit}')
        if [ -n "$IFACE" ]; then
          ip route del default || true
          ip route add default via #{GATEWAY} dev "$IFACE"
        fi

        # DNS via systemd-resolved
        mkdir -p /etc/systemd/resolved.conf.d
        cat >/etc/systemd/resolved.conf.d/99-custom-dns.conf <<EOF
[Resolve]
DNS=#{DNS.join(" ")}
FallbackDNS=
Domains=
MulticastDNS=no
LLMNR=no
DNSSEC=no
EOF
        systemctl restart systemd-resolved || true
      SHELL

      # Copy your SSH public key for direct SSH access
      ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip rescue nil
      ssh_pub_key ||= File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip rescue nil
      
      if ssh_pub_key
        vm.vm.provision "shell", privileged: false, inline: <<-SHELL
          echo "Adding your SSH public key to authorized_keys..."
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          echo '#{ssh_pub_key}' >> ~/.ssh/authorized_keys
          chmod 600 ~/.ssh/authorized_keys
        SHELL
        
        vm.vm.provision "shell", privileged: true, inline: <<-SHELL
          echo "Adding your SSH public key to root authorized_keys..."
          mkdir -p /root/.ssh
          chmod 700 /root/.ssh
          echo '#{ssh_pub_key}' >> /root/.ssh/authorized_keys
          chmod 600 /root/.ssh/authorized_keys
        SHELL
      end
    end
  end
end
```

**Important**: After creating the file, you need to identify your network interface.

### 3.2: Identify Your Network Interface

```bash
# On macOS/Linux
ifconfig | grep -A 1 "192.168.[4-7]"

# Or use ip command
ip addr show | grep "192.168.[4-7]"
```

**Example output**:
```
en2: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.5.10 netmask 0xfffffc00 broadcast 192.168.7.255
```

In this example, the interface is `en2: Wi-Fi (AirPort)`.

### 3.3: Update Vagrantfile with Your Interface

Edit the Vagrantfile and update line 35 to specify your bridge interface:

```ruby
# Before (line 35)
        # bridge: "en0: Wi-Fi (AirPort)"

# After (replace with YOUR interface)
        bridge: "en2: Wi-Fi (AirPort)"
```

**Save the file**.

---

## Step 4: Launch Virtual Machines

### 4.1: Start VMs

```bash
cd ~/homelabs

# Start all VMs (this will take 10-15 minutes)
vagrant up
```

**What happens**:
1. Downloads Debian Bookworm base box (~350MB, first time only)
2. Creates 4 VMs
3. Configures networking
4. Installs required packages
5. Configures kernel parameters for Kubernetes
6. Sets up SSH keys

### 4.2: Monitor Progress

You'll see output like:
```
Bringing machine 'master' up with 'virtualbox' provider...
Bringing machine 'worker1' up with 'virtualbox' provider...
...
==> master: Box 'debian/bookworm64' could not be found...
==> master: Adding box 'debian/bookworm64'
```

**Wait for completion**. You should see:
```
==> master: Machine 'master' has a post `vagrant up` message...
==> worker1: Machine 'worker1' has a post `vagrant up` message...
==> worker2: Machine 'worker2' has a post `vagrant up` message...
==> worker3: Machine 'worker3' has a post `vagrant up` message...
```

### 4.3: Verify VMs

```bash
# Check VM status
vagrant status
```

**Expected output**:
```
Current machine states:

master                    running (virtualbox)
worker1                   running (virtualbox)
worker2                   running (virtualbox)
worker3                   running (virtualbox)
```

---

## Step 5: Configure SSH Access

### 5.1: Test Vagrant SSH

```bash
# Test SSH through Vagrant
vagrant ssh master -c "hostname && whoami"
```

**Expected output**:
```
master
vagrant
```

### 5.2: Test Direct SSH

```bash
# Test direct SSH (should work without password)
ssh vagrant@192.168.5.200 "hostname && whoami"
```

**Expected output**:
```
master
vagrant
```

### 5.3: Create SSH Helper Script

Create `ssh-nodes.sh`:

```bash
cat > ~/homelabs/ssh-nodes.sh << 'EOF'
#!/bin/bash
# Quick SSH helper for homelabs cluster nodes

case "$1" in
  master|m)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.200
    ;;
  worker1|w1)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.201
    ;;
  worker2|w2)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.202
    ;;
  worker3|w3)
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.5.203
    ;;
  *)
    echo "Usage: $0 {master|m|worker1|w1|worker2|w2|worker3|w3}"
    exit 1
    ;;
esac
EOF

chmod +x ~/homelabs/ssh-nodes.sh
```

**Test it**:
```bash
./ssh-nodes.sh master
# You should be logged into the master node
exit
```

---

## Step 6: Install k3s Cluster

### 6.1: Create k3s Master Installation Script

Create `install-k3s-master.sh`:

```bash
cat > ~/homelabs/install-k3s-master.sh << 'EOF'
#!/bin/bash
# Install k3s master node with observability stack

set -euo pipefail

echo "=== Installing k3s master node ==="

# Install k3s server
curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --node-ip 192.168.5.200 \
  --node-external-ip 192.168.5.200 \
  --bind-address 192.168.5.200 \
  --advertise-address 192.168.5.200 \
  --tls-san 192.168.5.200

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
until kubectl get nodes &>/dev/null; do
  sleep 2
done

echo "=== k3s master installed successfully ==="
echo "Node token:"
sudo cat /var/lib/rancher/k3s/server/node-token
echo ""
echo "Kubeconfig is available at: /etc/rancher/k3s/k3s.yaml"
EOF

chmod +x ~/homelabs/install-k3s-master.sh
```

### 6.2: Create k3s Worker Installation Script

Create `install-k3s-worker.sh`:

```bash
cat > ~/homelabs/install-k3s-worker.sh << 'EOF'
#!/bin/bash
# Install k3s worker node

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <MASTER_IP> <NODE_TOKEN>"
  exit 1
fi

MASTER_IP=$1
NODE_TOKEN=$2
CURRENT_IP=$(hostname -I | awk '{print $2}')

echo "=== Installing k3s worker on $HOSTNAME ($CURRENT_IP) ==="
echo "Joining cluster at: $MASTER_IP"

# Install k3s agent
curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" \
  K3S_TOKEN="${NODE_TOKEN}" sh -s - agent \
  --node-ip "${CURRENT_IP}" \
  --node-external-ip "${CURRENT_IP}"

echo "=== k3s worker installed successfully ==="
EOF

chmod +x ~/homelabs/install-k3s-worker.sh
```

### 6.3: Install k3s on Master Node

```bash
cd ~/homelabs

# Copy script to master
scp install-k3s-master.sh root@192.168.5.200:/tmp/

# Execute installation
ssh root@192.168.5.200 'bash /tmp/install-k3s-master.sh'
```

**This takes 1-2 minutes**. You'll see:
```
=== Installing k3s master node ===
[INFO]  Finding release for channel stable
[INFO]  Using v1.33.5+k3s1 as release
...
=== k3s master installed successfully ===
Node token:
K10xxxxxxxxxxxx::server:xxxxxxxxxxxxx
```

**Important**: Copy the node token shown at the end!

### 6.4: Get Node Token

```bash
# Get the token (save this for the next step)
NODE_TOKEN=$(ssh root@192.168.5.200 'cat /var/lib/rancher/k3s/server/node-token')
echo "Node Token: $NODE_TOKEN"
```

### 6.5: Install k3s on Worker Nodes

```bash
# Install on all workers simultaneously
for ip in 192.168.5.201 192.168.5.202 192.168.5.203; do
  echo "Installing on $ip..."
  scp install-k3s-worker.sh root@$ip:/tmp/
  ssh root@$ip "bash /tmp/install-k3s-worker.sh 192.168.5.200 $NODE_TOKEN" &
done

# Wait for all to complete
wait
echo "All workers installed!"
```

**This takes 1-2 minutes per worker**.

### 6.6: Configure kubectl on Your Machine

```bash
# Create .kube directory
mkdir -p ~/.kube

# Copy kubeconfig from master
ssh root@192.168.5.200 'cat /etc/rancher/k3s/k3s.yaml' | \
  sed "s/127.0.0.1/192.168.5.200/g" > ~/.kube/config

# Set permissions
chmod 600 ~/.kube/config

# Set environment variable (add to ~/.bashrc or ~/.zshrc for persistence)
export KUBECONFIG=~/.kube/config
```

### 6.7: Verify Cluster

```bash
# Check nodes
kubectl get nodes -o wide
```

**Expected output** (wait 30 seconds if nodes show NotReady):
```
NAME      STATUS   ROLES                  AGE   VERSION        INTERNAL-IP     EXTERNAL-IP
master    Ready    control-plane,master   2m    v1.33.5+k3s1   192.168.5.200   192.168.5.200
worker1   Ready    <none>                 1m    v1.33.5+k3s1   192.168.5.201   192.168.5.201
worker2   Ready    <none>                 1m    v1.33.5+k3s1   192.168.5.202   192.168.5.202
worker3   Ready    <none>                 1m    v1.33.5+k3s1   192.168.5.203   192.168.5.203
```

✅ **Checkpoint**: You now have a working 4-node k3s cluster!

---

## Step 7: Install Observability Stack

### 7.1: Create Observability Installation Script

Create `install-observability.sh`:

```bash
cat > ~/homelabs/install-observability.sh << 'EOF'
#!/bin/bash
# Install observability stack: Prometheus, Grafana, Loki

set -euo pipefail

# Set kubeconfig for k3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Installing Observability Stack ==="

# Wait for cluster to be ready
echo "Checking cluster status..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Add Helm (k3s doesn't include it by default)
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
echo "Installing Prometheus + Grafana..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30080 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=30093 \
  --wait --timeout=10m

# Install Loki for log aggregation
echo "Installing Loki..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set promtail.enabled=true \
  --set grafana.enabled=false \
  --wait --timeout=5m

# Configure Loki datasource in Grafana
echo "Configuring Loki datasource..."
cat <<DATASOURCE | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasource-loki
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      isDefault: false
      editable: true
DATASOURCE

# Restart Grafana to pick up Loki datasource
echo "Restarting Grafana..."
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring
kubectl rollout status deployment kube-prometheus-stack-grafana -n monitoring --timeout=5m

echo ""
echo "=== Observability Stack Installed Successfully ==="
echo ""
echo "Access URLs (from your host machine):"
echo "  Grafana:       http://192.168.5.200:30080"
echo "    Username: admin"
echo "    Password: admin"
echo ""
echo "  Prometheus:    http://192.168.5.200:30090"
echo "  Alertmanager:  http://192.168.5.200:30093"
echo ""
EOF

chmod +x ~/homelabs/install-observability.sh
```

### 7.2: Install Observability Stack

```bash
cd ~/homelabs

# Copy script to master
scp install-observability.sh root@192.168.5.200:/tmp/

# Execute installation (this takes 5-10 minutes)
ssh root@192.168.5.200 'bash /tmp/install-observability.sh'
```

**What happens**:
1. Installs Helm package manager
2. Adds Prometheus and Grafana Helm repositories
3. Installs kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
4. Installs Loki stack (Loki, Promtail)
5. Configures Loki as a datasource in Grafana

**This takes 5-10 minutes**. You'll see:
```
=== Installing Observability Stack ===
Checking cluster status...
Installing Helm...
Adding Helm repositories...
Installing Prometheus + Grafana...
Installing Loki...
=== Observability Stack Installed Successfully ===
```

### 7.3: Verify Observability Pods

```bash
# Check all monitoring pods
kubectl get pods -n monitoring
```

**Expected output** (all pods should be Running):
```
NAME                                                        READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          3m
kube-prometheus-stack-grafana-xxx                           3/3     Running   0          3m
kube-prometheus-stack-kube-state-metrics-xxx                1/1     Running   0          3m
kube-prometheus-stack-operator-xxx                          1/1     Running   0          3m
kube-prometheus-stack-prometheus-node-exporter-xxx          1/1     Running   0          3m
loki-0                                                      1/1     Running   0          2m
loki-promtail-xxx                                           1/1     Running   0          2m
prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          3m
```

✅ **Checkpoint**: Observability stack is installed!

---

## Step 8: Verify Installation

### 8.1: Create Verification Script

Create `verify-cluster.sh`:

```bash
cat > ~/homelabs/verify-cluster.sh << 'EOF'
#!/bin/bash
# Verify k3s cluster and observability stack

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  k3s Cluster Verification                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

export KUBECONFIG=~/.kube/config

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check_mark="${GREEN}✓${NC}"
cross_mark="${RED}✗${NC}"

# Check kubectl
echo "🔍 Checking kubectl connectivity..."
if kubectl cluster-info &>/dev/null; then
    echo -e "  ${check_mark} kubectl is configured correctly"
else
    echo -e "  ${cross_mark} kubectl is NOT working"
    exit 1
fi

# Check nodes
echo ""
echo "🖥️  Checking cluster nodes..."
kubectl get nodes -o wide

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
READY_COUNT=$(kubectl get nodes --no-headers | grep -c Ready || true)

if [ "$NODE_COUNT" -eq 4 ] && [ "$READY_COUNT" -eq 4 ]; then
    echo -e "  ${check_mark} All 4 nodes are Ready"
else
    echo -e "  ${cross_mark} Expected 4 Ready nodes, found ${READY_COUNT}/${NODE_COUNT}"
fi

# Check monitoring
echo ""
echo "📊 Checking observability stack..."
kubectl get pods -n monitoring

# Check endpoints
echo ""
echo "🌐 Testing service endpoints..."

test_url() {
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$1" | grep -q "200\|302"; then
        echo -e "  ${check_mark} $2: $1"
    else
        echo -e "  ${cross_mark} $2: $1"
    fi
}

test_url "http://192.168.5.200:30080/login" "Grafana    "
test_url "http://192.168.5.200:30090/graph" "Prometheus "
test_url "http://192.168.5.200:30093" "Alertmanager"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Verification Complete!                                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Grafana: http://192.168.5.200:30080"
echo "   Username: admin | Password: admin"
echo ""
EOF

chmod +x ~/homelabs/verify-cluster.sh
```

### 8.2: Run Verification

```bash
cd ~/homelabs
./verify-cluster.sh
```

**Expected output**: All checks should show ✓ (green checkmarks).

---

## Step 9: Explore Grafana Dashboards

### 9.1: Open Grafana

```bash
# Open Grafana in your browser
open http://192.168.5.200:30080
# Or manually navigate to: http://192.168.5.200:30080
```

### 9.2: Login

- **Username**: `admin`
- **Password**: `admin`

(You may be prompted to change the password - you can skip this)

### 9.3: Explore Pre-configured Dashboards

1. Click the **☰ menu** (top left)
2. Click **Dashboards**
3. You'll see folders like:
   - **General**
   - **Kubernetes / Compute Resources**
   - **Node Exporter**

### 9.4: View Cluster Overview

1. Navigate to: **Dashboards** → **Kubernetes / Compute Resources** → **Cluster**
2. You'll see:
   - CPU Usage
   - Memory Usage
   - Network I/O
   - Disk I/O
   - Pod count
   - And more!

### 9.5: View Node Metrics

1. Navigate to: **Dashboards** → **Node Exporter** → **Nodes**
2. Select a node from the dropdown
3. You'll see detailed system metrics

### 9.6: Explore Logs with Loki

1. Click the **compass icon** (Explore) on the left sidebar
2. Select **Loki** as the datasource
3. Try these queries:
   ```
   {namespace="kube-system"}
   {namespace="monitoring"}
   {job="systemd-journal"}
   ```

---

## Step 10: Deploy Sample Application

### 10.1: Deploy Nginx

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx:latest --replicas=3

# Expose it as a NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the assigned port
kubectl get svc nginx
```

**Example output**:
```
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.43.123.45    <none>        80:31234/TCP   10s
```

### 10.2: Test the Application

```bash
# Access nginx (replace 31234 with your actual NodePort)
curl http://192.168.5.200:31234
```

**Expected output**: HTML content from nginx

### 10.3: View in Grafana

1. Go back to Grafana
2. Navigate to: **Dashboards** → **Kubernetes / Compute Resources** → **Pod**
3. Select namespace: **default**
4. Select pod: **nginx-xxx**
5. You'll see CPU, memory, and network metrics for your nginx pods!

### 10.4: View Nginx Logs

1. In Grafana, click **Explore**
2. Select **Loki**
3. Query: `{app="nginx"}`
4. You'll see nginx access logs

### 10.5: Cleanup Sample App (Optional)

```bash
kubectl delete deployment nginx
kubectl delete service nginx
```

---

## Troubleshooting

### Issue: VMs Don't Start

**Symptoms**: Vagrant fails to create VMs

**Solutions**:
```bash
# Check VirtualBox is running
vboxmanage list runningvms

# Check if VMs exist but are stopped
vboxmanage list vms

# Restart VirtualBox
# macOS: Open VirtualBox GUI and restart
# Linux: sudo systemctl restart virtualbox

# Try again
vagrant up
```

### Issue: Network Bridge Not Found

**Symptoms**: Vagrant prompts for network interface selection

**Solution**:
1. Identify your interface: `ifconfig` or `ip addr`
2. Edit Vagrantfile line 35:
   ```ruby
   bridge: "YOUR_INTERFACE_NAME"
   ```
3. Reload VMs:
   ```bash
   vagrant reload
   ```

### Issue: kubectl Connection Refused

**Symptoms**: `kubectl get nodes` fails

**Solutions**:
```bash
# Re-copy kubeconfig
ssh root@192.168.5.200 'cat /etc/rancher/k3s/k3s.yaml' | \
  sed "s/127.0.0.1/192.168.5.200/g" > ~/.kube/config

# Set environment variable
export KUBECONFIG=~/.kube/config

# Test connection
kubectl get nodes
```

### Issue: Grafana Not Accessible

**Symptoms**: Can't access http://192.168.5.200:30080

**Solutions**:
```bash
# Check if Grafana pod is running
kubectl get pods -n monitoring | grep grafana

# Check service
kubectl get svc -n monitoring | grep grafana

# Restart Grafana
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring

# Wait for it to be ready
kubectl rollout status deployment kube-prometheus-stack-grafana -n monitoring

# Test from command line
curl http://192.168.5.200:30080/login
```

### Issue: Pods Stuck in Pending

**Symptoms**: `kubectl get pods -A` shows pods in Pending state

**Solutions**:
```bash
# Describe the pod to see why
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# 1. Insufficient resources - check node resources:
kubectl top nodes  # Requires metrics-server

# 2. Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 3. Restart the pod
kubectl delete pod <pod-name> -n <namespace>
```

### Issue: Node Shows NotReady

**Symptoms**: `kubectl get nodes` shows NotReady status

**Solutions**:
```bash
# Check node details
kubectl describe node <node-name>

# SSH to the node
ssh root@<node-ip>

# Check k3s service
systemctl status k3s  # on master
systemctl status k3s-agent  # on worker

# Restart k3s
systemctl restart k3s  # on master
systemctl restart k3s-agent  # on worker

# Check logs
journalctl -u k3s -f  # on master
journalctl -u k3s-agent -f  # on worker
```

---

## Daily Operations

### Starting the Cluster

```bash
cd ~/homelabs

# Start all VMs
vagrant up

# Wait 30 seconds for k3s to start
sleep 30

# Verify
kubectl get nodes
./verify-cluster.sh
```

### Stopping the Cluster

```bash
cd ~/homelabs

# Gracefully stop all VMs
vagrant halt

# Or stop individual nodes
vagrant halt master
vagrant halt worker1
```

### Accessing Nodes

```bash
# Via helper script
./ssh-nodes.sh master

# Via direct SSH
ssh vagrant@192.168.5.200
ssh root@192.168.5.200

# Via Vagrant
vagrant ssh master
```

### Viewing Logs

```bash
# Kubernetes events
kubectl get events -A --sort-by='.lastTimestamp'

# Pod logs
kubectl logs <pod-name> -n <namespace>

# Follow logs
kubectl logs <pod-name> -n <namespace> -f

# Previous container logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous

# All containers in a pod
kubectl logs <pod-name> -n <namespace> --all-containers
```

### Monitoring Cluster Health

```bash
# Node status
kubectl get nodes -o wide

# Pod status across all namespaces
kubectl get pods -A

# System pods
kubectl get pods -n kube-system

# Monitoring pods
kubectl get pods -n monitoring

# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A
```

### Updating Observability Stack

```bash
# SSH to master
ssh root@192.168.5.200

# Update Helm repos
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm repo update

# Upgrade Prometheus/Grafana
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# Upgrade Loki
helm upgrade loki grafana/loki-stack --namespace monitoring
```

---

## Cleanup and Maintenance

### Removing Observability Stack

```bash
# SSH to master
ssh root@192.168.5.200

# Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Remove Helm releases
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall loki -n monitoring

# Delete namespace
kubectl delete namespace monitoring
```

### Removing k3s

```bash
# On master
ssh root@192.168.5.200 '/usr/local/bin/k3s-uninstall.sh'

# On workers
ssh root@192.168.5.201 '/usr/local/bin/k3s-agent-uninstall.sh'
ssh root@192.168.5.202 '/usr/local/bin/k3s-agent-uninstall.sh'
ssh root@192.168.5.203 '/usr/local/bin/k3s-agent-uninstall.sh'
```

### Destroying VMs

```bash
cd ~/homelabs

# Stop and delete all VMs
vagrant destroy -f

# This removes all VMs but keeps your Vagrantfile
# You can recreate them with: vagrant up
```

### Recreating the Cluster

```bash
cd ~/homelabs

# Destroy old VMs
vagrant destroy -f

# Create fresh VMs
vagrant up

# Reinstall k3s
./setup-cluster.sh  # If you created the automated script
# Or follow steps 6 and 7 manually
```

### Disk Space Management

```bash
# Check VM disk usage
for ip in 192.168.5.{200..203}; do
  echo "=== $ip ==="
  ssh root@$ip "df -h /"
done

# Clean Docker/containerd images on nodes
for ip in 192.168.5.{200..203}; do
  ssh root@$ip "k3s crictl rmi --prune"
done

# Clean up unused Kubernetes resources
kubectl delete pods --field-selector status.phase=Failed -A
kubectl delete pods --field-selector status.phase=Succeeded -A
```

---

## Appendix: Reference Information

### Port Reference

| Service | Port | Type | Access |
|---------|------|------|--------|
| k3s API | 6443 | TCP | Master only |
| Grafana | 30080 | NodePort | Any node |
| Prometheus | 30090 | NodePort | Any node |
| Alertmanager | 30093 | NodePort | Any node |
| Loki | 3100 | ClusterIP | Internal only |
| SSH | 22 | TCP | All nodes |

### IP Allocation

| Node | IP Address | Purpose |
|------|------------|---------|
| master | 192.168.5.200 | Control plane, monitoring |
| worker1 | 192.168.5.201 | Workloads |
| worker2 | 192.168.5.202 | Workloads |
| worker3 | 192.168.5.203 | Workloads |

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | admin |
| SSH (vagrant) | vagrant | vagrant |
| SSH (root) | root | (key-based) |

### Useful kubectl Commands

```bash
# Context and config
kubectl config view
kubectl config current-context
kubectl cluster-info

# Nodes
kubectl get nodes
kubectl describe node <node-name>
kubectl cordon <node-name>  # Mark unschedulable
kubectl uncordon <node-name>  # Mark schedulable
kubectl drain <node-name>  # Evict all pods

# Pods
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- bash

# Deployments
kubectl get deployments -A
kubectl scale deployment <name> --replicas=3
kubectl rollout status deployment <name>
kubectl rollout restart deployment <name>

# Services
kubectl get svc -A
kubectl describe svc <service-name>

# Resources
kubectl api-resources
kubectl explain pod
kubectl explain deployment.spec

# Debugging
kubectl get events -A --sort-by='.lastTimestamp'
kubectl top nodes
kubectl top pods -A
```

### Additional Resources

- **k3s Documentation**: https://docs.k3s.io/
- **Vagrant Documentation**: https://www.vagrantup.com/docs
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Loki Documentation**: https://grafana.com/docs/loki/

---

## Success Checklist

Use this checklist to verify your setup:

- [ ] VirtualBox installed and working
- [ ] Vagrant installed and working
- [ ] All 4 VMs created and running
- [ ] SSH access working to all nodes
- [ ] k3s master node installed
- [ ] All 3 worker nodes joined cluster
- [ ] kubectl configured on host machine
- [ ] All 4 nodes show "Ready" status
- [ ] Monitoring namespace created
- [ ] All monitoring pods running
- [ ] Grafana accessible at http://192.168.5.200:30080
- [ ] Prometheus accessible at http://192.168.5.200:30090
- [ ] Can login to Grafana
- [ ] Pre-configured dashboards visible
- [ ] Loki datasource configured
- [ ] Sample application deployed successfully
- [ ] Metrics visible in Grafana for sample app

---

## Congratulations! 🎉

You now have a fully functional 4-node k3s Kubernetes cluster with comprehensive observability!

**What you've built**:
- Production-like Kubernetes cluster
- Full monitoring with Prometheus
- Beautiful dashboards with Grafana
- Centralized logging with Loki
- Alert management with Alertmanager
- Complete infrastructure as code

**What you can do next**:
1. Deploy real applications
2. Experiment with Helm charts
3. Set up CI/CD pipelines
4. Test autoscaling
5. Implement GitOps with ArgoCD
6. Add a service mesh (Istio, Linkerd)
7. Deploy databases
8. Create custom Grafana dashboards
9. Configure alerts
10. Learn Kubernetes operators

Happy clustering! 🚀

