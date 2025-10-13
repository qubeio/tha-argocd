# Monitoring Stack Documentation

## Architecture Overview

The Thanos fleet-manager cluster includes a complete observability stack for monitoring metrics and logs across all workloads.

### Components

- **Prometheus**: Metrics collection and storage
- **Loki**: Log aggregation and storage  
- **Grafana Alloy**: Unified telemetry collector (replaces Promtail)
- **Grafana**: Visualization and dashboards

## Why Grafana Alloy Instead of Promtail?

[Grafana Alloy](https://grafana.com/blog/2024/04/09/grafana-alloy-opentelemetry-collector-with-prometheus-pipelines/) is the modern replacement for Promtail and Grafana Agent:

- **Unified Collector**: Handles metrics, logs, traces, and profiles in one tool
- **OpenTelemetry Compatible**: Future-ready for distributed tracing
- **Modern Configuration**: Uses declarative River configuration language
- **Better Performance**: More efficient resource usage than Promtail
- **Active Development**: Promtail is being deprecated in favor of Alloy

## Storage and Retention Policies

### Prometheus
- **Storage**: 10Gi PersistentVolume using `standard` StorageClass (kind's local-path)
- **Retention**: 15 days
- **Purpose**: Kubernetes metrics, application metrics, system metrics

### Loki
- **Storage**: 20Gi PersistentVolume using `standard` StorageClass (kind's local-path)
- **Retention**: 30 days (configurable via compactor)
- **Purpose**: Container logs, application logs, audit logs

### Total Disk Usage
- **Maximum**: ~30Gi for monitoring data
- **Storage Location**: `/var/local-path-provisioner/` on kind nodes (maps to Ubuntu host)

## Access URLs

### External Access (via Traefik)
- **Grafana Dashboard**: http://grafana.test
  - Username: `admin`
  - Password: `admin`
- **Prometheus UI**: http://prometheus.test
- **Loki UI**: http://loki.test

### Internal Service URLs (for data sources)
- **Prometheus**: `http://kube-prometheus-stack-prometheus.monitoring:9090`
- **Loki**: `http://loki.monitoring:3100`

## How to Use

### Querying Metrics in Grafana

Access Grafana at http://grafana.test and use the **Prometheus** data source:

**Basic Queries (PromQL)**:
```
# All running pods
up

# CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# Pod count per namespace
count by (namespace) (kube_pod_info)
```

### Querying Logs in Grafana

Use the **Loki** data source for log queries:

**Basic Log Queries (LogQL)**:
```
# All logs from monitoring namespace
{namespace="monitoring"}

# Logs from specific pod
{pod="grafana-xxx"}

# Logs containing "error"
{namespace="monitoring"} |= "error"

# Logs from last hour
{namespace="monitoring"} |= "error" | json | line_format "{{.message}}"
```

### Monitoring Disk Usage

Check storage usage for monitoring components:

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check disk usage inside kind nodes
docker exec fleet-manager-control-plane df -h | grep local-path-provisioner
docker exec fleet-manager-worker df -h | grep local-path-provisioner

# Check Loki storage
kubectl exec -n monitoring deployment/loki -- df -h /loki

# Check Prometheus storage
kubectl exec -n monitoring deployment/prometheus-server -- df -h /prometheus
```

## Troubleshooting

### Check Component Status

```bash
# Verify all monitoring pods are running
kubectl get pods -n monitoring

# Check pod logs
kubectl logs -n monitoring deployment/alloy
kubectl logs -n monitoring deployment/loki
kubectl logs -n monitoring deployment/prometheus-server
```

### Verify Data Sources

1. Access Grafana at http://grafana.test
2. Go to **Configuration** → **Data Sources**
3. Verify **Prometheus** and **Loki** are configured and accessible

### Adjust Retention (if disk space becomes an issue)

**Prometheus** (reduce retention):
```bash
# Edit the prometheus.yaml ArgoCD Application
# Change: prometheus.prometheusSpec.retention: "7d"  # from 15d
```

**Loki** (reduce retention):
```bash
# Edit the loki.yaml ArgoCD Application  
# Change: loki.limits_config.retention_period: "360h"  # from 720h (30d → 15d)
```

### Check Log Collection

Verify Alloy is collecting logs:

```bash
# Check Alloy targets (discovered pods)
kubectl exec -n monitoring deployment/alloy -- curl -s localhost:12345/-/targets

# Check if logs are flowing to Loki
kubectl exec -n monitoring deployment/loki -- curl -s localhost:3100/ready
```

## Configuration Files

- **Prometheus**: `/home/andreas/source/repos/argo/applications/fleet-manager/prometheus.yaml`
- **Loki**: `/home/andreas/source/repos/argo/applications/fleet-manager/loki.yaml`
- **Alloy**: `/home/andreas/source/repos/argo/applications/fleet-manager/alloy.yaml`
- **Grafana**: `/home/andreas/source/repos/argo/applications/fleet-manager/grafana.yaml`

## Future Enhancements

The monitoring stack is designed to be extensible:

- **Distributed Tracing**: Add Grafana Tempo for traces
- **Profiling**: Add Grafana Pyroscope for continuous profiling
- **Alerting**: Configure Prometheus alerts and Grafana notifications
- **Custom Dashboards**: Import or create dashboards for specific workloads
- **Multi-Cluster**: Extend to monitor child clusters in the fleet

---

**Last Updated**: 2025-01-13  
**Maintained by**: Thanos Platform Team
