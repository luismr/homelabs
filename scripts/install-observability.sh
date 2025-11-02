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
cat <<EOF | kubectl apply -f -
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
EOF

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
echo "Grafana comes with pre-configured dashboards:"
echo "  - Kubernetes / Compute Resources / Cluster"
echo "  - Kubernetes / Compute Resources / Namespace"
echo "  - Kubernetes / Compute Resources / Node"
echo "  - Kubernetes / Compute Resources / Pod"
echo "  - Node Exporter / Nodes"
echo ""
echo "Loki is available as a datasource in Grafana for log exploration."
echo ""

