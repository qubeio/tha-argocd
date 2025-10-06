# GitOps Infrastructure Management

## Overview

MetalLB and Traefik are now fully managed via GitOps using ArgoCD with sync waves to handle dependency ordering.

## Architecture

### Dependency Chain (Sync Waves)

```
Wave 1: MetalLB (Helm Chart)
   ↓
Wave 2: MetalLB Config (IPAddressPool + L2Advertisement)
   ↓
Wave 3: Traefik (Ingress Controller)
   ↓
Wave 4+: Applications (Grafana, etc.)
```

### Why This Approach?

**Before**: Infrastructure was imperatively installed via `thanos-cli.py` using kubectl/helm commands
- ❌ Two sources of truth (CLI + Git)
- ❌ No drift detection
- ❌ Manual updates required
- ❌ Not auditable

**After**: All infrastructure managed via GitOps
- ✅ Single source of truth (Git)
- ✅ Automatic drift detection and self-healing
- ✅ Version controlled changes
- ✅ Full audit trail
- ✅ Declarative updates

## Files Created

### ArgoCD Applications (argo/applications/fleet-manager/)

1. **metallb.yaml** - Wave 1
   - Installs MetalLB via Helm chart
   - Creates metallb-system namespace
   - Provides LoadBalancer capability

2. **metallb-config.yaml** - Wave 2
   - Applies IPAddressPool (10.100.200.50-70)
   - Applies L2Advertisement
   - Waits for Wave 1 to complete

3. **traefik.yaml** - Wave 3
   - Deploys Traefik DaemonSet
   - Creates LoadBalancer Service (uses MetalLB)
   - Provides ingress for all apps

### Manifests (argo/manifests/)

```
manifests/
├── metallb/
│   ├── ipaddresspool.yaml      # LoadBalancer IP range
│   └── l2advertisement.yaml    # Layer 2 mode config
└── traefik/
    ├── traefik-daemonset.yaml  # DaemonSet + RBAC
    ├── traefik-service.yaml    # LoadBalancer Service
    └── ingressclass.yaml       # IngressClass definition
```

## Updated CLI (thanos-cli.py)

### What Changed

1. **Removed** `install_metallb_and_traefik()` function (110 lines)
2. **Removed** imperative kubectl/helm commands
3. **Updated** help messages to reflect GitOps workflow

### New Workflow

```bash
# 1. Provision bare cluster
python thanos-cli.py provision-infrastructure

# 2. Bootstrap ArgoCD (which triggers infrastructure deployment)
python thanos-cli.py bootstrap-argocd

# 3. ArgoCD automatically installs:
#    - MetalLB (wave 1)
#    - MetalLB Config (wave 2)
#    - Traefik (wave 3)
#    - Applications (wave 4+)
```

## How Sync Waves Work

ArgoCD processes applications in wave order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
```

- Lower wave numbers deploy first
- ArgoCD waits for each wave to be healthy before proceeding
- If a wave fails, subsequent waves are blocked
- Automatic retry with exponential backoff

## Monitoring Deployment

### Via ArgoCD UI

1. Access: http://argocd.test
2. Login: admin / admin123
3. Watch applications sync in order

### Via CLI

```bash
# Watch all applications
kubectl get applications -n argocd -w

# Check specific app status
kubectl get application metallb -n argocd -o yaml

# View sync waves in action
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave",STATUS:.status.sync.status
```

### Expected Timeline

- **Wave 1 (MetalLB)**: ~30-60 seconds
  - Helm chart install
  - Controller + Speaker pods ready

- **Wave 2 (MetalLB Config)**: ~10-20 seconds
  - CRD resources applied
  - IP pool configured

- **Wave 3 (Traefik)**: ~30-45 seconds
  - DaemonSet deployed
  - LoadBalancer IP assigned
  - Health checks passing

- **Wave 4+ (Apps)**: Varies per app
  - Parallel deployment of applications
  - Ingress routes configured

## Making Changes

### Update Infrastructure

```bash
# 1. Edit manifests in argo/manifests/
vim argo/manifests/traefik/traefik-service.yaml

# 2. Commit and push to Gitea
cd argo
git add manifests/
git commit -m "Update Traefik LoadBalancer IP"
git push

# 3. ArgoCD auto-syncs (usually within 3 minutes)
# Or manually sync via UI/CLI
```

### Update Application Definition

```bash
# 1. Edit Application manifest
vim argo/applications/fleet-manager/traefik.yaml

# 2. Commit and push
git add applications/
git commit -m "Update Traefik sync policy"
git push

# 3. ArgoCD will update the Application resource
```

## Troubleshooting

### App Stuck in Progressing

```bash
# Check app status
kubectl describe application metallb -n argocd

# Check sync status
argocd app get metallb

# Manual sync with detailed output
argocd app sync metallb --prune
```

### Wave Not Progressing

```bash
# Check if previous wave is healthy
kubectl get applications -n argocd

# Force sync specific wave
kubectl patch application metallb -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'
```

### Rollback Changes

```bash
# ArgoCD tracks sync history
argocd app history metallb

# Rollback to previous revision
argocd app rollback metallb <revision-id>
```

## Benefits Realized

1. **Declarative**: All infra defined in Git
2. **Automated**: No manual kubectl commands
3. **Ordered**: Sync waves handle dependencies
4. **Resilient**: Auto-healing on drift
5. **Auditable**: Full Git history
6. **Testable**: Can preview changes in ArgoCD
7. **Portable**: Easy to recreate environments

## Next Steps

Consider moving these to GitOps as well:
- CoreDNS configuration
- Network policies
- Monitoring stack (Prometheus, Grafana)
- Logging stack (Loki, Promtail)
- Backup solutions

All infrastructure should be managed via GitOps for consistency!

