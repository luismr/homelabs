# Loki Log Collection Guide

## How Loki Collects Logs from All Pods

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │    Node 1    │  │    Node 2    │  │    Node 3    │     │
│  │              │  │              │  │              │     │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │     │
│  │  │ Pod A  │  │  │  │ Pod B  │  │  │  │ Pod C  │  │     │
│  │  └───┬────┘  │  │  └───┬────┘  │  │  └───┬────┘  │     │
│  │      │ logs  │  │      │ logs  │  │      │ logs  │     │
│  │      ▼       │  │      ▼       │  │      ▼       │     │
│  │  /var/log/   │  │  /var/log/   │  │  /var/log/   │     │
│  │  pods/       │  │  pods/       │  │  pods/       │     │
│  │      ▲       │  │      ▲       │  │      ▲       │     │
│  │      │       │  │      │       │  │      │       │     │
│  │  ┌───┴────┐  │  │  ┌───┴────┐  │  │  ┌───┴────┐  │     │
│  │  │Promtail│  │  │  │Promtail│  │  │  │Promtail│  │     │
│  │  └───┬────┘  │  │  └───┬────┘  │  │  └───┬────┘  │     │
│  └──────┼───────┘  └──────┼───────┘  └──────┼───────┘     │
│         │                 │                 │             │
│         └─────────────────┼─────────────────┘             │
│                           ▼                               │
│                      ┌─────────┐                          │
│                      │  Loki   │                          │
│                      │ Server  │                          │
│                      └────┬────┘                          │
│                           │                               │
│                           ▼                               │
│                      ┌─────────┐                          │
│                      │ Grafana │                          │
│                      │(Explore)│                          │
│                      └─────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

### How It Works

1. **Container Logs**: All container stdout/stderr logs are written to `/var/log/pods/` on each node
2. **Promtail DaemonSet**: One Promtail pod runs on each node (4 total in your cluster)
3. **Volume Mount**: Each Promtail pod mounts `/var/log/pods` from the host
4. **Log Discovery**: Promtail automatically discovers new log files
5. **Labels**: Promtail adds Kubernetes metadata (namespace, pod, container, etc.)
6. **Forwarding**: Promtail sends logs to Loki server
7. **Storage**: Loki stores and indexes logs
8. **Query**: Grafana queries Loki using LogQL

## Current Status

✅ **Promtail is running on all nodes**:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
```

✅ **Loki is collecting logs from these namespaces**:
- `kube-system` - System components (coredns, metrics-server, etc.)
- `monitoring` - Observability stack (Prometheus, Grafana, Loki itself)
- **Any new namespace** - Automatically added when pods are created

## Verification Commands

### 1. Check Promtail Pods

```bash
# View Promtail DaemonSet
kubectl get daemonset loki-promtail -n monitoring

# View Promtail pods (should be 4 - one per node)
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o wide

# Check Promtail logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50
```

### 2. Check What Namespaces Have Logs

```bash
# Query Loki for available namespaces
kubectl exec -n monitoring loki-0 -- wget -q -O- \
  'http://localhost:3100/loki/api/v1/label/namespace/values'
```

### 3. Check What Pods Have Logs

```bash
# Query Loki for available pods
kubectl exec -n monitoring loki-0 -- wget -q -O- \
  'http://localhost:3100/loki/api/v1/label/pod/values'
```

### 4. Test Log Query

```bash
# Get recent logs from kube-system namespace
kubectl exec -n monitoring loki-0 -- wget -q -O- \
  'http://localhost:3100/loki/api/v1/query_range?query={namespace="kube-system"}&limit=10'
```

## Querying Logs in Grafana

### Access Grafana

1. Open: http://192.168.5.200:30080
2. Login: `admin` / `admin`
3. Click the **compass icon** (🧭 Explore) in the left sidebar

### Select Loki Datasource

At the top, select **Loki** from the dropdown

### LogQL Query Examples

#### 1. All logs from a namespace

```logql
{namespace="kube-system"}
```

#### 2. All logs from a specific pod

```logql
{pod="coredns-64fd4b4794-4zswt"}
```

#### 3. All logs from a specific container

```logql
{namespace="monitoring", container="grafana"}
```

#### 4. Logs from all pods with a label

```logql
{app="grafana"}
```

#### 5. Filter logs containing specific text

```logql
{namespace="kube-system"} |= "error"
```

#### 6. Filter logs NOT containing text

```logql
{namespace="kube-system"} != "info"
```

#### 7. Logs from multiple namespaces

```logql
{namespace=~"kube-system|monitoring"}
```

#### 8. Logs from a specific node

```logql
{node_name="master"}
```

#### 9. Count error logs

```logql
sum(count_over_time({namespace="kube-system"} |= "error" [5m]))
```

#### 10. Rate of logs per second

```logql
rate({namespace="kube-system"}[1m])
```

### Time Range

Use the time picker in the top-right corner:
- Last 5 minutes
- Last 1 hour
- Last 6 hours
- Custom range

### Live Tailing

Click the **▶️ Live** button in the top-right to stream logs in real-time!

## Common Use Cases

### Debug a Failing Pod

```bash
# 1. Find the pod
kubectl get pods -n <namespace>

# 2. In Grafana Explore, query:
{namespace="<namespace>", pod="<pod-name>"}

# 3. Look for ERROR, WARN, or stack traces
{namespace="<namespace>", pod="<pod-name>"} |~ "ERROR|WARN|Exception"
```

### Monitor Application Logs

```logql
# All logs from your app
{namespace="default", app="myapp"}

# Only errors
{namespace="default", app="myapp"} |= "ERROR"

# Errors in the last 5 minutes
{namespace="default", app="myapp"} |= "ERROR" [5m]
```

### Check System Health

```logql
# CoreDNS errors
{namespace="kube-system", app="kube-dns"} |= "error"

# Kubelet issues
{job="systemd-journal", unit="kubelet.service"} |= "error"

# Container restarts
{namespace=~".*"} |= "restarting"
```

### Audit Who Did What

```logql
# API server audit logs (if enabled)
{namespace="kube-system", app="kube-apiserver"}

# User actions
{job="systemd-journal"} |~ "kubectl|user"
```

## Deploying Apps to Test Log Collection

### Deploy Sample Nginx App

```bash
# Create deployment
kubectl create deployment nginx --image=nginx --replicas=2

# Generate some logs
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://nginx
```

### Query Nginx Logs in Grafana

```logql
{app="nginx"}
```

You should see nginx access logs!

### Deploy App with Custom Logs

Create `test-logger.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-generator
  labels:
    app: log-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
    spec:
      containers:
      - name: logger
        image: busybox
        command:
        - sh
        - -c
        - |
          i=0
          while true; do
            i=$((i+1))
            echo "INFO: Log message $i at $(date)"
            if [ $((i % 5)) -eq 0 ]; then
              echo "WARN: Warning message $i"
            fi
            if [ $((i % 10)) -eq 0 ]; then
              echo "ERROR: Error message $i"
            fi
            sleep 2
          done
```

Deploy it:

```bash
kubectl apply -f test-logger.yaml
```

Query in Grafana:

```logql
# All logs
{app="log-generator"}

# Only errors
{app="log-generator"} |= "ERROR"

# Count by level
sum by (level) (count_over_time({app="log-generator"} | regexp "(?P<level>INFO|WARN|ERROR)" [5m]))
```

## Advanced Configuration

### Adding More Labels

If you want to add custom labels to Promtail, edit the ConfigMap:

```bash
# Edit Promtail config
kubectl edit configmap loki-loki-stack -n monitoring

# Or update via Helm
helm upgrade loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set promtail.config.snippets.extraScrapeConfigs=<your-config>
```

### Filtering Out Noisy Logs

You can configure Promtail to drop certain logs:

```yaml
# In Promtail config
- drop:
    expression: '.*debug.*'
    source: content
```

### Increasing Retention

```bash
# Update Loki retention (default is 30 days)
helm upgrade loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.config.chunk_store_config.max_look_back_period=744h  # 31 days
```

## Troubleshooting

### Logs Not Appearing

1. **Check Promtail is running**:
   ```bash
   kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
   ```

2. **Check Promtail logs for errors**:
   ```bash
   kubectl logs -n monitoring loki-promtail-<pod-id> --tail=100
   ```

3. **Verify Loki is reachable**:
   ```bash
   kubectl exec -n monitoring loki-promtail-<pod-id> -- \
     wget -q -O- http://loki:3100/ready
   ```

4. **Check Loki logs**:
   ```bash
   kubectl logs -n monitoring loki-0 --tail=100
   ```

### Loki Running Out of Disk Space

```bash
# Check disk usage
kubectl exec -n monitoring loki-0 -- df -h /data

# Reduce retention or add more storage
helm upgrade loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.size=20Gi
```

### Promtail Not Picking Up New Pods

```bash
# Restart Promtail DaemonSet
kubectl rollout restart daemonset loki-promtail -n monitoring
```

### Grafana Can't Query Loki

1. **Check datasource**:
   - Go to Grafana → Configuration → Data Sources
   - Select Loki
   - Click "Test" button at the bottom

2. **Verify Loki service**:
   ```bash
   kubectl get svc -n monitoring loki
   ```

3. **Test from Grafana pod**:
   ```bash
   kubectl exec -n monitoring <grafana-pod> -- \
     curl http://loki:3100/ready
   ```

## Performance Optimization

### Reduce Log Volume

Filter out debug logs at Promtail level:

```yaml
pipeline_stages:
  - match:
      selector: '{namespace="default"}'
      stages:
      - drop:
          source: "content"
          expression: ".*DEBUG.*"
```

### Limit Log Rate

Prevent log flooding:

```yaml
limits_config:
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
```

### Query Performance

Use these techniques for faster queries:

1. **Add time range**: `[5m]` instead of searching all logs
2. **Filter early**: Use `|= "error"` before complex parsing
3. **Limit results**: Add `| limit 100` to queries
4. **Use labels**: `{namespace="x"}` is faster than grep-style filtering

## Summary

✅ **Loki is already collecting logs from ALL pods**
✅ **Promtail runs on every node as a DaemonSet**
✅ **Logs are automatically discovered from `/var/log/pods`**
✅ **New pods/namespaces are automatically included**
✅ **Access logs via Grafana Explore or Loki API**

### Quick Test

1. Open Grafana: http://192.168.5.200:30080
2. Click Explore (compass icon)
3. Select "Loki" datasource
4. Enter query: `{namespace="kube-system"}`
5. Click "Run query"
6. You should see logs! 🎉

### Next Steps

- Create Grafana dashboards with log panels
- Set up alerts based on log patterns
- Deploy your applications and monitor their logs
- Use LogQL for advanced log analysis

**Your Loki setup is working perfectly!** 🚀

