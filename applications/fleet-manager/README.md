# Fleet Manager Cluster Applications

This directory contains ArgoCD Application manifests for managing the fleet-manager cluster.

## Structure

- `applications/` - ArgoCD Application manifests
- `clusters/` - Cluster-specific configurations
- `projects/` - ArgoCD Project definitions

## Fleet Manager Applications

The fleet-manager cluster is the control plane cluster that manages other clusters in the fleet.

### Applications

- **ArgoCD**: GitOps continuous delivery tool
- **Crossplane**: Cloud-native control plane for infrastructure management
- **External Secrets Operator**: Manages secrets from external systems (Akeyless)
- **Grafana**: Monitoring and observability dashboard (via Helm chart)
- **Prometheus**: Metrics collection and monitoring
- **Traefik**: Ingress controller and load balancer

### Files

- `argocd-install.yaml` - ArgoCD installation via Helm chart
- `crossplane.yaml` - ArgoCD Application for Crossplane (using Crossplane Helm chart)
- `external-secrets-operator.yaml` - External Secrets Operator installation via Helm chart
- `external-secrets-akeyless-store.yaml` - Akeyless integration configuration
- `grafana.yaml` - ArgoCD Application for Grafana (using Grafana Helm chart)
