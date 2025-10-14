# Alloy Log Collection Configuration

This document describes the Alloy configuration for collecting Kubernetes pod logs and shipping them to Loki.

## Overview

Alloy is deployed as a DaemonSet that runs on each node in the cluster, collecting logs from all pods and forwarding them to Loki. The configuration uses Grafana Alloy's native components to discover log files, extract metadata, and ship logs efficiently.

## Architecture

```
Pod Logs (/var/log/pods/)
  → local.file_match (discovery)
  → loki.source.file (tailing)
  → loki.process (label extraction)
  → loki.write (ship to Loki)
```

## Configuration Approach

### Why This Approach?

The configuration uses `local.file_match` instead of Kubernetes service discovery because:

1. **Direct File Access**: Alloy runs on the host and has direct access to `/var/log/pods/`
2. **Glob Pattern Support**: `local.file_match` properly handles filesystem glob patterns like `/var/log/pods/*/*/*.log`
3. **Simplicity**: No need for Kubernetes API queries or complex relabeling rules
4. **Reliability**: Works even if Kubernetes API is slow or unavailable

### Key Components

#### 1. File Discovery (`local.file_match`)

```alloy
local.file_match "pod_logs" {
  path_targets = [{
    __path__ = "/var/log/pods/*/*/*.log",
  }]
}
```

Discovers all pod log files using a glob pattern. The path structure is:
- `/var/log/pods/<namespace>_<podname>_<uid>/<container>/<sequence>.log`

#### 2. Log Tailing (`loki.source.file`)

```alloy
loki.source.file "pod_logs" {
  targets    = local.file_match.pod_logs.targets
  forward_to = [loki.process.add_labels.receiver]
}
```

Tails discovered log files and forwards entries to the processing pipeline.

#### 3. Label Extraction (`loki.process`)

```alloy
loki.process "add_labels" {
  stage.regex {
    expression = "^/var/log/pods/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_[^/]+/(?P<container>[^/]+)/.*\\.log$"
    source     = "filename"
  }

  stage.labels {
    values = {
      namespace = "",
      pod       = "pod_name",
      container = "",
    }
  }

  forward_to = [loki.write.loki.receiver]
}
```

Extracts metadata from the file path:
- **namespace**: Kubernetes namespace
- **pod**: Pod name
- **container**: Container name

These become Loki labels for querying.

#### 4. Loki Writer (`loki.write`)

```alloy
loki.write "loki" {
  endpoint {
    url = "http://loki.monitoring:3100/loki/api/v1/push"
  }
}
```

Ships processed logs to Loki via HTTP.

## Deployment Configuration

### DaemonSet Deployment

```yaml
controller:
  type: "daemonset"
```

Ensures Alloy runs on every node to collect logs from all pods.

### Host Path Mount

```yaml
alloy:
  mounts:
    varlog: true  # Mount /var/log from host
```

Required to access pod logs at `/var/log/pods/` on the host filesystem.

### RBAC Permissions

Alloy's ServiceAccount has permissions to:
- List and watch pods (for metadata enrichment if needed)
- Read pod logs via the `/pods/log` API endpoint

## Querying Logs in Loki

### By Pod Name
```logql
{pod="grafana-7f55f59754-4x2kd"}
```

### By Namespace
```logql
{namespace="monitoring"}
```

### By Container
```logql
{container="loki"}
```

### Combined
```logql
{namespace="default", pod="log-generator"}
```

## Troubleshooting

### Check Alloy Status

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
```

### View Alloy Logs

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy -c alloy
```

### Verify Log Discovery

```bash
# Check if Alloy can see log files
kubectl exec -n monitoring <alloy-pod> -c alloy -- ls /var/log/pods/
```

### Query Loki Labels

```bash
# Check which pods are being logged
curl -s "http://loki.test/loki/api/v1/label/pod/values" | jq
```

### Common Issues

#### No Logs Appearing in Loki

1. **Check Alloy pod is running**:
   ```bash
   kubectl get pods -n monitoring | grep alloy
   ```

2. **Check for errors in Alloy logs**:
   ```bash
   kubectl logs -n monitoring <alloy-pod> -c alloy | grep -i error
   ```

3. **Verify mount is working**:
   ```bash
   kubectl exec -n monitoring <alloy-pod> -c alloy -- ls -la /var/log/pods/ | head
   ```

4. **Check Loki is reachable**:
   ```bash
   kubectl exec -n monitoring <alloy-pod> -c alloy -- wget -O- http://loki.monitoring:3100/ready
   ```

#### Configuration Errors

If the Alloy pod is crash-looping, check the logs for syntax errors:
```bash
kubectl logs -n monitoring <alloy-pod> -c alloy
```

Common syntax issues:
- Missing trailing commas in map/array definitions
- Incorrect component names or references
- Invalid regex patterns

## Implementation Notes

### Why Not `discovery.kubernetes`?

An earlier approach used `discovery.kubernetes` with relabeling rules to construct file paths. This failed because:

1. **Glob Pattern Issues**: When using label substitution like `__path__ = "/var/log/pods/*$1/*/*.log"`, the wildcards (`*`) are treated as literals by `stat()`, not as glob patterns
2. **Separator Problems**: Alloy's default separator (`;`) was being inserted between source labels, breaking the path
3. **Complexity**: Required complex relabeling rules to construct paths from metadata

The `local.file_match` approach is simpler and more reliable because it uses the filesystem's native glob support.

### File Path Structure

Kubernetes stores pod logs with this structure:
```
/var/log/pods/<namespace>_<podname>_<pod-uid>/<container>/<sequence>.log
```

Examples:
- `/var/log/pods/default_log-generator_c9730e0e-eae2-4dc0-aaa6-41f8a67c0e1d/log-generator/0.log`
- `/var/log/pods/monitoring_loki-0_79c13372-0982-4698-ba75-3f60e259f0d1/loki/0.log`

The regex in `loki.process` extracts the namespace, pod name, and container from this path.

## Performance Considerations

- **DaemonSet Model**: One Alloy pod per node means log collection scales linearly with cluster size
- **Local File Access**: Reading from local disk is faster than querying the Kubernetes API for logs
- **Resource Limits**: Configured with modest limits (500m CPU, 512Mi memory) suitable for moderate workloads
- **Label Cardinality**: Only essential labels (namespace, pod, container) are extracted to avoid high cardinality in Loki

## Configuration File Location

The Alloy configuration is managed via ArgoCD:
- **Application**: `applications/fleet-manager/alloy.yaml`
- **Sync Policy**: Automated with prune and selfHeal enabled
- **ConfigMap**: Generated by Helm chart, controlled by `alloy.configMap.content` value

## Related Components

- **Loki**: Log aggregation system (applications/fleet-manager/loki.yaml)
- **Grafana**: Visualization and querying UI (applications/fleet-manager/grafana.yaml)
- **Prometheus**: Metrics collection for monitoring the monitoring stack
