# ArgoCD GitOps Repository

This repository contains the GitOps configuration for managing the Thanos multi-cluster orchestration platform using ArgoCD.

## Repository Structure

```
argocd/
├── applications/           # ArgoCD Application manifests
│   └── fleet-manager/      # Fleet manager cluster applications
├── clusters/               # Cluster configurations
├── projects/               # ArgoCD Project definitions
└── README.md              # This file
```

## Fleet Manager Cluster

The fleet-manager cluster is the control plane cluster that manages other clusters in the fleet.

### Applications

- **ArgoCD**: GitOps continuous delivery tool
- **Grafana**: Monitoring and observability dashboard
- **Prometheus**: Metrics collection and monitoring
- **Traefik**: Ingress controller and load balancer

### Cluster Configuration

The fleet-manager cluster is configured with:

- **API Server**: <https://10.100.0.2:6443>
- **Network**: 10.100.0.0/16 (homelab network)
- **Ingress**: Traefik with hostname-based routing

## Bootstrap Process

1. **Deploy ArgoCD**: Use the bootstrap configuration to install ArgoCD
2. **Configure Access**: Set up ingress and authentication
3. **Register Cluster**: Add the fleet-manager cluster to ArgoCD
4. **Deploy Applications**: Deploy the fleet-manager applications

s
