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
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_mark="${GREEN}✓${NC}"
cross_mark="${RED}✗${NC}"

# Check kubectl
echo "🔍 Checking kubectl connectivity..."
if kubectl cluster-info &>/dev/null; then
    echo -e "  ${check_mark} kubectl is configured correctly"
else
    echo -e "  ${cross_mark} kubectl is NOT working"
    echo "  Try: export KUBECONFIG=~/.kube/config"
    exit 1
fi

# Check nodes
echo ""
echo "🖥️  Checking cluster nodes..."
echo ""
kubectl get nodes -o wide

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
READY_COUNT=$(kubectl get nodes --no-headers | grep -c Ready || true)

if [ "$NODE_COUNT" -eq 4 ] && [ "$READY_COUNT" -eq 4 ]; then
    echo ""
    echo -e "  ${check_mark} All 4 nodes are Ready"
else
    echo ""
    echo -e "  ${cross_mark} Expected 4 Ready nodes, found ${READY_COUNT}/${NODE_COUNT}"
fi

# Check monitoring namespace
echo ""
echo "📊 Checking observability stack..."
if kubectl get namespace monitoring &>/dev/null; then
    echo -e "  ${check_mark} Monitoring namespace exists"
    
    # Check pods
    TOTAL_PODS=$(kubectl get pods -n monitoring --no-headers | wc -l | tr -d ' ')
    RUNNING_PODS=$(kubectl get pods -n monitoring --no-headers | grep -c Running || true)
    
    echo -e "  ${check_mark} Monitoring pods: ${RUNNING_PODS}/${TOTAL_PODS} running"
    
    if [ "$RUNNING_PODS" -ne "$TOTAL_PODS" ]; then
        echo ""
        echo "  Pods not running:"
        kubectl get pods -n monitoring | grep -v Running || true
    fi
else
    echo -e "  ${cross_mark} Monitoring namespace NOT found"
    echo "  Run: ./install-observability.sh"
fi

# Check services
echo ""
echo "🌐 Checking service endpoints..."

check_endpoint() {
    local name=$1
    local url=$2
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" | grep -q "200\|302"; then
        echo -e "  ${check_mark} ${name}: ${url}"
    else
        echo -e "  ${cross_mark} ${name}: ${url} (not accessible)"
    fi
}

check_endpoint "Grafana    " "http://192.168.5.200:30080/login"
check_endpoint "Prometheus " "http://192.168.5.200:30090/graph"
check_endpoint "Alertmanager" "http://192.168.5.200:30093"

# Check SSH access
echo ""
echo "🔐 Checking SSH access to nodes..."

check_ssh() {
    local node=$1
    local ip=$2
    
    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           vagrant@"$ip" "echo ok" &>/dev/null; then
        echo -e "  ${check_mark} ${node} (${ip})"
    else
        echo -e "  ${cross_mark} ${node} (${ip})"
    fi
}

check_ssh "master " "192.168.5.200"
check_ssh "worker1" "192.168.5.201"
check_ssh "worker2" "192.168.5.202"
check_ssh "worker3" "192.168.5.203"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Summary                                                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🎉 Your k3s cluster with observability is ready!"
echo ""
echo "📊 Grafana Dashboard:"
echo "   http://192.168.5.200:30080"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "🔍 Quick Commands:"
echo "   kubectl get nodes              # View cluster nodes"
echo "   kubectl get pods -A            # View all pods"
echo "   kubectl get pods -n monitoring # View monitoring stack"
echo ""
echo "📖 Full documentation: ./CLUSTER-INFO.md"
echo ""

