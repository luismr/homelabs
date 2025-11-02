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
./ssh-nodes.sh master   # or: ./ssh-nodes.sh m
./ssh-nodes.sh worker1  # or: ./ssh-nodes.sh w1
./ssh-nodes.sh worker2  # or: ./ssh-nodes.sh w2
./ssh-nodes.sh worker3  # or: ./ssh-nodes.sh w3
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
./setup-cluster.sh
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
ssh root@192.168.5.200 < install-k3s-master.sh

# 2. Get the node token
NODE_TOKEN=$(ssh root@192.168.5.200 'cat /var/lib/rancher/k3s/server/node-token')

# 3. Install workers
ssh root@192.168.5.201 "bash -s -- 192.168.5.200 $NODE_TOKEN" < install-k3s-worker.sh
ssh root@192.168.5.202 "bash -s -- 192.168.5.200 $NODE_TOKEN" < install-k3s-worker.sh
ssh root@192.168.5.203 "bash -s -- 192.168.5.200 $NODE_TOKEN" < install-k3s-worker.sh

# 4. Copy kubeconfig
ssh root@192.168.5.200 'cat /etc/rancher/k3s/k3s.yaml' | \
  sed "s/127.0.0.1/192.168.5.200/g" > ~/.kube/config-homelabs
export KUBECONFIG=~/.kube/config-homelabs

# 5. Install observability stack
scp install-observability.sh root@192.168.5.200:/tmp/
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

