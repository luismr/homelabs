# k3s Cluster - Access Information

## 🎉 Cluster Status: READY

Your 4-node k3s cluster with full observability is up and running!

### Cluster Nodes

| Node    | IP Address      | Role           | Status | Version       |
|---------|-----------------|----------------|--------|---------------|
| master  | 192.168.5.200   | control-plane  | Ready  | v1.33.5+k3s1  |
| worker1 | 192.168.5.201   | worker         | Ready  | v1.33.5+k3s1  |
| worker2 | 192.168.5.202   | worker         | Ready  | v1.33.5+k3s1  |
| worker3 | 192.168.5.203   | worker         | Ready  | v1.33.5+k3s1  |

## 🔍 Observability Stack

### Access URLs

Open these URLs in your browser:

- **Grafana**: http://192.168.5.200:30080
  - Username: `admin`
  - Password: `admin`
  - Pre-configured dashboards for Kubernetes monitoring
  - Loki datasource configured for log exploration

- **Prometheus**: http://192.168.5.200:30090
  - Direct access to Prometheus UI
  - Query metrics and create custom queries

- **Alertmanager**: http://192.168.5.200:30093
  - Configure and view alerts

### Installed Components

✅ **Prometheus** - Metrics collection and storage (7 day retention)
✅ **Grafana** - Visualization and dashboards
✅ **Loki** - Log aggregation and querying
✅ **Promtail** - Log collection agent (running on all nodes)
✅ **Alertmanager** - Alert management
✅ **Node Exporter** - Host-level metrics (running on all nodes)
✅ **Kube State Metrics** - Kubernetes object metrics
✅ **Prometheus Operator** - Kubernetes-native Prometheus management

## 📊 Pre-configured Grafana Dashboards

Once logged into Grafana, explore these dashboards:

1. **Kubernetes / Compute Resources / Cluster** - Overall cluster view
2. **Kubernetes / Compute Resources / Namespace** - Per-namespace resources
3. **Kubernetes / Compute Resources / Node** - Node-level details
4. **Kubernetes / Compute Resources / Pod** - Pod-level metrics
5. **Node Exporter / Nodes** - Host system metrics

## 🚀 Quick Start Commands

### kubectl Configuration

```bash
# Set your kubeconfig
export KUBECONFIG=~/.kube/config

# View cluster nodes
kubectl get nodes -o wide

# View all pods
kubectl get pods -A

# View monitoring stack
kubectl get all -n monitoring
```

### Common Operations

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# View monitoring logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f

# View Loki logs
kubectl logs -n monitoring -l app=loki -f

# Port forward to services (if NodePort doesn't work)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

### Deploy Sample Application

```bash
# Deploy a sample nginx app to test
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# Check the assigned NodePort
kubectl get svc nginx

# Access it (replace <NodePort> with the actual port)
curl http://192.168.5.200:<NodePort>
```

## 🔧 SSH Access

### Direct SSH to Nodes

```bash
# SSH as vagrant user
ssh vagrant@192.168.5.200  # master
ssh vagrant@192.168.5.201  # worker1
ssh vagrant@192.168.5.202  # worker2
ssh vagrant@192.168.5.203  # worker3

# SSH as root
ssh root@192.168.5.200     # master (root)
```

### Helper Script

```bash
./ssh-nodes.sh master   # Quick SSH to master
./ssh-nodes.sh w1       # Quick SSH to worker1
./ssh-nodes.sh w2       # Quick SSH to worker2
./ssh-nodes.sh w3       # Quick SSH to worker3
```

## 📈 Monitoring Examples

### View Metrics in Prometheus

1. Open http://192.168.5.200:30090
2. Try these queries:
   - `node_cpu_seconds_total` - CPU usage
   - `node_memory_MemAvailable_bytes` - Available memory
   - `kube_pod_container_status_running` - Running containers
   - `container_cpu_usage_seconds_total` - Container CPU usage

### View Logs in Grafana

1. Open http://192.168.5.200:30080
2. Go to "Explore" (compass icon)
3. Select "Loki" datasource
4. Use LogQL queries:
   - `{namespace="kube-system"}` - All kube-system logs
   - `{app="nginx"}` - Logs from nginx pods
   - `{job="systemd-journal"}` - System journal logs

### Create Custom Dashboards

1. Login to Grafana
2. Click "+" → "Dashboard"
3. Add panels with Prometheus queries
4. Use Loki for log panels

## 🛠️ Troubleshooting

### Check Pod Status

```bash
# See all pods in monitoring namespace
kubectl get pods -n monitoring

# Describe a problematic pod
kubectl describe pod <pod-name> -n monitoring

# View pod logs
kubectl logs <pod-name> -n monitoring
```

### Restart Monitoring Services

```bash
# Restart Grafana
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring

# Restart Prometheus
kubectl delete pod prometheus-kube-prometheus-stack-prometheus-0 -n monitoring

# Restart Loki
kubectl rollout restart statefulset loki -n monitoring
```

### Check Service Endpoints

```bash
# List all services
kubectl get svc -n monitoring

# Check endpoints
kubectl get endpoints -n monitoring
```

## 🗑️ Cleanup

### Remove Observability Stack Only

```bash
# SSH to master
ssh root@192.168.5.200

# Remove helm releases
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall loki -n monitoring

# Delete namespace
kubectl delete namespace monitoring
```

### Destroy Entire Cluster

```bash
# Stop k3s on all nodes
ssh root@192.168.5.200 '/usr/local/bin/k3s-uninstall.sh'
ssh root@192.168.5.201 '/usr/local/bin/k3s-agent-uninstall.sh'
ssh root@192.168.5.202 '/usr/local/bin/k3s-agent-uninstall.sh'
ssh root@192.168.5.203 '/usr/local/bin/k3s-agent-uninstall.sh'

# Or destroy VMs completely
vagrant destroy -f
```

## 📚 Additional Resources

- **k3s Documentation**: https://docs.k3s.io/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Loki Documentation**: https://grafana.com/docs/loki/
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/

## 🎯 Next Steps

Now that your cluster is ready with full observability, you can:

1. Deploy containerized applications
2. Set up CI/CD pipelines
3. Test microservices architectures
4. Experiment with service meshes (Istio, Linkerd)
5. Deploy databases (PostgreSQL, MongoDB, Redis)
6. Test autoscaling with HPA
7. Implement GitOps with ArgoCD or Flux

Enjoy your homelab! 🚀

