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

