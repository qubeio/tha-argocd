# Fleet Manager Cluster Applications

This directory contains ArgoCD Application manifests for managing the fleet-manager cluster.

## Structure

- `applications/` - ArgoCD Application manifests
- `clusters/` - Cluster-specific configurations
- `projects/` - ArgoCD Project definitions

## Fleet Manager Applications

The fleet-manager cluster is the control plane cluster that manages other clusters in the fleet.

### Applications

- **ArgoCD**: GitOps continuous delivery tool (self-managed)
- **Crossplane**: Cloud-native control plane for infrastructure management (Azure Key Vault integration)
- **External Secrets Operator**: Manages secrets from external systems (Azure Key Vault)
- **Grafana**: Monitoring and observability dashboard (via Helm chart)
- **MetalLB**: LoadBalancer service provider
- **Traefik**: Ingress controller and load balancer

### Files

- `argocd-install.yaml` - ArgoCD installation via Helm chart (self-managed)
- `crossplane.yaml` - Crossplane core installation via Helm chart
- `crossplane-config.yaml` - Crossplane Azure Key Vault provider and configuration
- `crossplane/` - Crossplane provider configurations and examples
- `external-secrets-operator.yaml` - External Secrets Operator installation via Helm chart
- `external-secrets-stores.yaml` - External Secrets stores (Azure Key Vault)
- `external-secrets/` - External Secrets configurations and examples
- `grafana.yaml` - Grafana installation via Helm chart
- `metallb.yaml` - MetalLB installation
- `metallb-config.yaml` - MetalLB IP address pool configuration
- `traefik.yaml` - Traefik ingress controller installation
