#!/bin/bash
# Automated k3s cluster setup with observability

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  k3s Cluster Setup with Observability Stack                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
MASTER_IP="192.168.5.200"
WORKER_IPS=("192.168.5.201" "192.168.5.202" "192.168.5.203")
WORKER_NAMES=("worker1" "worker2" "worker3")

# Step 1: Install k3s on master
echo "[1/4] Installing k3s on master node..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${MASTER_IP} 'bash -s' < install-k3s-master.sh

# Get the node token
echo ""
echo "[2/4] Retrieving node token from master..."
NODE_TOKEN=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${MASTER_IP} 'cat /var/lib/rancher/k3s/server/node-token')
echo "Node token retrieved."

# Wait a bit for master to stabilize
sleep 10

# Step 2: Install k3s on workers
echo ""
echo "[3/4] Installing k3s on worker nodes..."
for i in "${!WORKER_IPS[@]}"; do
  WORKER_IP="${WORKER_IPS[$i]}"
  WORKER_NAME="${WORKER_NAMES[$i]}"
  echo "  -> Installing on ${WORKER_NAME} (${WORKER_IP})..."
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${WORKER_IP} "bash -s -- ${MASTER_IP} ${NODE_TOKEN}" < install-k3s-worker.sh &
done

# Wait for all worker installations to complete
wait
echo "All workers installed."

# Wait for cluster to stabilize
sleep 15

# Step 3: Copy kubeconfig to local machine
echo ""
echo "[4/4] Setting up kubectl access..."
mkdir -p ~/.kube
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${MASTER_IP} 'cat /etc/rancher/k3s/k3s.yaml' | \
  sed "s/127.0.0.1/${MASTER_IP}/g" > ~/.kube/config-homelabs
chmod 600 ~/.kube/config-homelabs

# Merge with existing kubeconfig or set as default
if [ -f ~/.kube/config ]; then
  echo "Kubeconfig saved to: ~/.kube/config-homelabs"
  echo "To use it, run: export KUBECONFIG=~/.kube/config-homelabs"
else
  cp ~/.kube/config-homelabs ~/.kube/config
  echo "Kubeconfig saved to: ~/.kube/config"
fi

export KUBECONFIG=~/.kube/config-homelabs

# Verify cluster
echo ""
echo "Verifying cluster..."
kubectl get nodes -o wide

# Step 4: Install observability stack
echo ""
read -p "Install observability stack (Prometheus, Grafana, Loki)? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  echo ""
  echo "Installing observability stack on master node..."
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null install-observability.sh root@${MASTER_IP}:/tmp/
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${MASTER_IP} 'bash /tmp/install-observability.sh'
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Cluster Setup Complete! 🎉                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Cluster Information:"
echo "  Master:   192.168.5.200"
echo "  Worker1:  192.168.5.201"
echo "  Worker2:  192.168.5.202"
echo "  Worker3:  192.168.5.203"
echo ""
echo "To use kubectl from your machine:"
echo "  export KUBECONFIG=~/.kube/config-homelabs"
echo "  kubectl get nodes"
echo ""
echo "Access Grafana:"
echo "  http://192.168.5.200:30080"
echo "  Username: admin"
echo "  Password: admin"
echo ""

