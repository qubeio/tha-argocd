# ArgoCD GitOps Repository

This repository contains the GitOps configuration for managing the Thanos multi-cluster orchestration platform using ArgoCD.

## Repository Structure

```
argo/
├── applications/              # ArgoCD Application manifests
│   └── fleet-manager/         # Fleet manager cluster applications
│       ├── app-of-apps.yaml       # App-of-apps Application
│       ├── argocd-install.yaml    # ArgoCD self-management
│       ├── fleet-manager-project.yaml # AppProject definition
│       ├── grafana.yaml           # Grafana monitoring
│       ├── metallb.yaml           # MetalLB LoadBalancer
│       ├── metallb-config.yaml    # MetalLB configuration
│       ├── repository-secret.yaml # Git repository connection
│       └── traefik.yaml           # Traefik ingress controller
├── clusters/                  # Cluster configurations
│   └── fleet-manager.yaml     # Fleet manager cluster config
├── docs/                     # Documentation
│   ├── CHANGES.md            # Change log
│   ├── GITOPS-INFRASTRUCTURE.md # Infrastructure docs
│   └── TESTING.md            # Testing documentation
├── manifests/                # Raw Kubernetes manifests
│   ├── metallb/              # MetalLB configuration
│   └── traefik/              # Traefik configuration
└── README.md                 # This file
```

## Fleet Manager Cluster

The fleet-manager cluster is the control plane cluster that manages other clusters in the fleet.

### Applications

- **ArgoCD**: GitOps continuous delivery tool (self-managed)
- **Grafana**: Monitoring and observability dashboard
- **Traefik**: Ingress controller and load balancer
- **MetalLB**: LoadBalancer service provider

### Cluster Configuration

The fleet-manager cluster is configured with:

- **API Server**: <https://10.100.200.2:6443>
- **Network**: 10.100.0.0/16 (homelab network)
- **Ingress**: Traefik with hostname-based routing
- **LoadBalancer**: MetalLB providing IPs from 10.100.200.100-10.100.200.150

## Bootstrap Process

The bootstrap process is automated via `thanos-cli.py` and follows a multi-stage approach:

### Stage 1: Infrastructure Setup

```bash
cd /path/to/thanos
python thanos-cli.py provision-infrastructure
```

This creates:

- Docker network (homelab)
- Kind cluster (fleet-manager)
- MetalLB for LoadBalancer services
- Traefik for ingress

### Stage 2: ArgoCD Bootstrap

```bash
python thanos-cli.py bootstrap-argocd
```

This installs:

1. ArgoCD via Helm with initial configuration
2. Applies bootstrap manifests directly from `applications/fleet-manager/`
3. Establishes GitOps connectivity to this repository

### Stage 3: Self-Management (Automatic)

Once bootstrapped, ArgoCD automatically:

1. Connects to Gitea repository (`http://gitea.test/andreas/argo.git`)
2. Creates the `fleet-manager` AppProject
3. Deploys the app-of-apps Application
4. Syncs all applications from `applications/fleet-manager/`
5. Manages its own installation via `argocd-install.yaml`

See [docs/GITOPS-INFRASTRUCTURE.md](./docs/GITOPS-INFRASTRUCTURE.md) for detailed architecture and troubleshooting.

## Making Changes

All changes to the cluster should be made via Git:

1. **Edit manifests** in this repository
2. **Commit and push** to Gitea
3. **ArgoCD syncs automatically** (or manually via UI)

### Example: Update ArgoCD Configuration

```bash
# Edit the ArgoCD configuration
vim applications/fleet-manager/argocd-install.yaml

# Commit and push
git add applications/fleet-manager/argocd-install.yaml
git commit -m "Update ArgoCD configuration"
git push

# ArgoCD will automatically detect and apply changes
```

## Access Information

- **ArgoCD UI**: <http://argocd.test>
- **Username**: admin
- **Password**: admin123 (configured in `argocd-install.yaml`)
- **Git Repository**: <http://gitea.test/andreas/argo.git>
- **Namespace**: argocd
- There is a helper in the thanos-cli to set credentials for argocd-cli too.

## Directory Details

### applications/fleet-manager/

Contains ArgoCD Application manifests for the fleet-manager cluster. Each file defines one application to be deployed.

### clusters/

Contains cluster-specific configurations for the fleet-manager cluster.

### docs/

Contains documentation including change logs, infrastructure details, and testing guides.

### manifests/

Contains raw Kubernetes manifests for MetalLB and Traefik configurations that are referenced by ArgoCD Applications.

## Key Features

✅ **Self-Managing ArgoCD**: ArgoCD manages its own installation via GitOps  
✅ **App-of-Apps Pattern**: All applications managed from a single repository  
✅ **Automated Sync**: Changes in Git are automatically applied to the cluster  
✅ **Secure by Default**: RBAC policies and project isolation  
✅ **Circular Reference Prevention**: Smart exclusions prevent infinite loops

## Next Steps

1. **Add more applications** by creating new files in `applications/fleet-manager/`
2. **Configure monitoring** by editing `grafana.yaml`
3. **Set up additional clusters** and add them to ArgoCD
4. **Implement GitOps workflows** for your development teams.
