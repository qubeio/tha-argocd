# GITOPS FLEET MANAGEMENT

## Proposed Folder Structure

argo/
├── applications/ # ArgoCD Application manifests (per-cluster)
│ ├── fleet-manager/ # Control plane cluster (existing)
│ │ ├── app-of-apps.yaml
│ │ ├── argocd-install.yaml
│ │ ├── fleet-manager-project.yaml
│ │ └── ...
│ ├── prod-cluster-01/ # Production workload cluster
│ │ ├── app-of-apps.yaml
│ │ ├── prod-project.yaml
│ │ └── ...
│ └── dev-cluster/ # Development cluster
│ ├── app-of-apps.yaml
│ └── ...
│
├── applicationsets/ # NEW: Cross-cluster application management
│ ├── system/ # Infrastructure apps (deployed to all/most clusters)
│ │ ├── cert-manager.yaml
│ │ ├── external-dns.yaml
│ │ └── monitoring-stack.yaml
│ └── workloads/ # Application workloads
│ ├── api-services.yaml
│ └── frontend-apps.yaml
│
├── clusters/ # Cluster registration secrets
│ ├── fleet-manager.yaml # Control plane (existing)
│ ├── prod-cluster-01.yaml
│ └── dev-cluster.yaml
│
├── manifests/ # Kubernetes manifests (organized by type)
│ ├── base/ # NEW: Shared base manifests
│ │ ├── metallb/
│ │ ├── traefik/
│ │ └── monitoring/
│ ├── overlays/ # NEW: Cluster-specific customizations
│ │ ├── fleet-manager/
│ │ │ ├── metallb/
│ │ │ └── traefik/
│ │ ├── prod-cluster-01/
│ │ └── dev-cluster/
│ └── shared/ # NEW: Truly shared resources (no customization)
│ └── network-policies/
│
├── projects/ # NEW: ArgoCD AppProject definitions
│ ├── fleet-manager-project.yaml
│ ├── production-project.yaml
│ └── development-project.yaml
│
└── docs/
├── MULTI-CLUSTER-STRATEGY.md # NEW: This strategy doc
└── ...
