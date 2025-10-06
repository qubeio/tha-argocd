# Infrastructure Manifests

This directory contains Kubernetes manifests for infrastructure components managed by ArgoCD.

## Directory Structure

```
manifests/
├── metallb/          # MetalLB configuration (IPAddressPool, L2Advertisement)
└── traefik/          # Traefik ingress controller manifests
```

## GitOps Deployment Order

These manifests are deployed via ArgoCD Applications with sync waves to ensure proper dependency ordering:

1. **Wave 1**: MetalLB Helm Chart (`metallb.yaml`)
   - Installs MetalLB controller and speaker
   - Provides LoadBalancer capability to the cluster

2. **Wave 2**: MetalLB Configuration (`metallb-config.yaml`)
   - Applies IPAddressPool (10.100.200.50-70)
   - Applies L2Advertisement
   - Depends on MetalLB CRDs being available

3. **Wave 3**: Traefik (`traefik.yaml`)
   - Deploys Traefik ingress controller (DaemonSet)
   - Creates LoadBalancer Service (depends on MetalLB)
   - Provides ingress for all applications

4. **Wave 4+**: Applications
   - All applications deployed via app-of-apps
   - Use Traefik for ingress routing

## Source of Truth

These manifests are synced from the `argo` GitOps repository:
- Repository: `https://github.com/qubeio/tha-argocd.git`
- Applications defined in: `applications/fleet-manager/`

## Editing Manifests

1. Make changes to manifests in this directory
2. Commit and push to Gitea
3. ArgoCD will automatically detect changes and sync (automated sync policy)
4. Changes are auditable via Git history

## Notes

- All infrastructure is now managed via GitOps
- No more imperative kubectl apply commands needed
- Changes are version controlled and auditable
- ArgoCD provides drift detection and self-healing

