# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an ArgoCD GitOps repository for managing the Thanos multi-cluster orchestration platform. It uses the app-of-apps pattern with ArgoCD managing its own installation and all infrastructure components via declarative Kubernetes manifests.

**Important Context:**
- Repository URL: https://github.com/qubeio/tha-argocd.git
- Main branch: main
- ArgoCD self-manages via `applications/fleet-manager/argocd-install.yaml`
- Bootstrap is handled by `thanos-cli.py` (located in separate thanos repository)

## Repository Structure

```
applications/
├── fleet-manager/     # Control plane cluster applications (primary)
├── nprod1/           # Non-production cluster 1
└── prod1/            # Production cluster 1

manifests/            # Raw Kubernetes manifests (MetalLB, Traefik, CLI API)
clusters/             # Cluster-specific configurations
docs/                 # Documentation
```

## Key Architecture Patterns

### App-of-Apps Pattern

The `app-of-apps.yaml` in each cluster directory manages all applications for that cluster:
- Excludes itself to prevent circular dependencies
- Uses automated sync with prune and selfHeal enabled
- All `.yaml` files in `applications/fleet-manager/` are synced except `app-of-apps.yaml`

### Multi-Source Applications

Some applications (like Grafana) use ArgoCD's multi-source feature:
- Primary source: Helm chart repository
- Values source: This Git repository with `ref: values`
- Values are split into modular files under `applications/fleet-manager/values/<app>/`

Example from grafana.yaml:
```yaml
sources:
  - repoURL: https://grafana.github.io/helm-charts
    chart: grafana
    helm:
      valueFiles:
        - $values/applications/fleet-manager/values/grafana/ingress.yaml
        - $values/applications/fleet-manager/values/grafana/auth.yaml
  - repoURL: https://github.com/qubeio/tha-argocd.git
    ref: values
```

### Self-Managing ArgoCD

ArgoCD manages its own installation:
- Uses Helm chart from https://argoproj.github.io/argo-helm
- Skips Helm hooks to avoid conflicts with existing installation
- Has `ignoreDifferences` for self-managed secrets
- Admin credentials: admin/admin123 (bcrypt hash in manifest)

## Fleet Manager Cluster Applications

**Infrastructure (Wave 1-3):**
- MetalLB (LoadBalancer, IP pool 10.100.200.50-70)
- Traefik (Ingress controller)
- MetalLB Config (IPAddressPool, L2Advertisement)

**Orchestration & Secrets:**
- ArgoCD (self-managed via Helm)
- Crossplane (Azure provider for infrastructure provisioning)
- External Secrets Operator (Azure Key Vault integration)

**Monitoring Stack:**
- Prometheus (kube-prometheus-stack, 15d retention, 10Gi storage)
- Loki (SingleBinary mode, 30d retention, 20Gi storage)
- Grafana (with Prometheus and Loki datasources)
- Alloy (metrics and logs collection)

**Other:**
- CLI API (REST API for CLI commands via Unix socket)
- Kind Clusters (for nested cluster management)

## Working with Applications

### Adding a New Application

1. Create a new `.yaml` file in `applications/fleet-manager/`
2. Follow existing patterns (see `grafana.yaml` or `prometheus.yaml` as examples)
3. Add to the `fleet-manager` AppProject if needed (see `fleet-manager-project.yaml`)
4. Commit and push - ArgoCD syncs automatically

### Modifying Existing Applications

1. Edit the Application manifest in `applications/fleet-manager/`
2. For Helm-based apps, modify parameters or valueFiles
3. For multi-source apps with values, edit files in `applications/fleet-manager/values/<app>/`
4. Commit and push - changes sync automatically via ArgoCD

### Sync Policies

Most applications use:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

ArgoCD's self-management adds:
```yaml
syncOptions:
  - ServerSideApply=true
  - Replace=true
  - SkipHooks=true
```

## Access Information

- **ArgoCD UI:** http://argocd.test
- **Admin credentials:** admin / admin123
- **Prometheus:** http://prometheus.test
- **Grafana:** http://grafana.test
- **Loki:** http://loki.test
- **API Server:** https://10.100.200.2:6443
- **Network:** 10.100.0.0/16

## Important Files

- `applications/fleet-manager/app-of-apps.yaml` - Manages all fleet-manager applications
- `applications/fleet-manager/argocd-install.yaml` - ArgoCD self-management
- `applications/fleet-manager/fleet-manager-project.yaml` - AppProject with source repos and RBAC
- `applications/fleet-manager/repository-secret.yaml` - Git repository connection secret

## Bootstrap Process

**Note:** Bootstrap is handled by `thanos-cli.py` in the parent thanos repository.

1. **Infrastructure Setup:** `python thanos-cli.py provision-infrastructure`
   - Creates Docker network, Kind cluster, MetalLB, Traefik

2. **ArgoCD Bootstrap:** `python thanos-cli.py bootstrap-argocd`
   - Installs ArgoCD via Helm with initial config
   - Applies bootstrap manifests from this repo
   - Establishes GitOps connectivity

3. **Self-Management (Automatic):**
   - ArgoCD connects to GitHub, creates AppProject, deploys app-of-apps
   - All applications in `applications/fleet-manager/` sync automatically
   - ArgoCD manages its own configuration going forward

## Common Patterns

### Excluding Files from App-of-Apps

In `app-of-apps.yaml`:
```yaml
directory:
  include: "*.yaml"
  exclude: "{app-of-apps.yaml}"
```

### Helm Parameters

Use the `helm.parameters` array for simple overrides:
```yaml
helm:
  parameters:
    - name: deploymentMode
      value: "SingleBinary"
```

### Multiple Value Files

Use `helm.valueFiles` with multi-source:
```yaml
helm:
  valueFiles:
    - $values/applications/fleet-manager/values/app/file1.yaml
    - $values/applications/fleet-manager/values/app/file2.yaml
```

## Monitoring Stack Notes

### Loki Configuration

- Runs in SingleBinary (monolithic) mode
- **All microservice replicas explicitly set to 0** to prevent deployment
- Gateway disabled - uses main ingress instead
- Schema: v11 with boltdb-shipper (structured metadata disabled)
- Retention: 30 days (720h), compactor enabled

### Prometheus Configuration

- Uses kube-prometheus-stack chart
- Alertmanager and bundled Grafana disabled (separate Grafana installation)
- Retention: 15 days

### Grafana Configuration

- Datasources for both Prometheus and Loki
- Auth configuration separated into modular value files
- Ingress at grafana.test

## Crossplane & External Secrets

Both integrate with Azure Key Vault:
- Crossplane: Infrastructure provisioning (Azure provider)
- External Secrets Operator: Runtime secret management
- Configuration files in respective subdirectories with examples
- Verification script: `applications/fleet-manager/crossplane/verify-setup.sh`

## GitOps Workflow

All changes flow through Git:
1. Edit manifests in this repository
2. Commit and push to main branch
3. ArgoCD automatically detects and syncs changes
4. No manual `kubectl apply` needed

Changes are:
- Version controlled
- Auditable via Git history
- Automatically applied with drift detection
- Self-healing if manual changes are made to cluster
