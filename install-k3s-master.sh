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

