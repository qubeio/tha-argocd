# ArgoCD Self-Management Bootstrap

This document explains how ArgoCD is configured to manage itself via GitOps using a single source of truth pattern.

## Architecture

The bootstrap process follows a simplified two-stage approach:

### Stage 1: Bootstrap (thanos-cli.py)
The `thanos-cli.py` script applies all manifests directly from the argo GitOps repository:

1. **Repository Secret** (`repository-secret.yaml`)
   - Configures connection to Gitea repository
   - URL: `http://gitea.test/andreas/argo.git`
   - Enables ArgoCD to pull from the GitOps repo

2. **AppProject** (`fleet-manager-project.yaml`)
   - Creates the `fleet-manager` project
   - Defines allowed source repositories (Helm charts, Gitea)
   - Sets up RBAC and destination permissions

3. **App-of-Apps** (`app-of-apps.yaml`)
   - Creates the main Application that manages all other applications
   - Points to `applications/fleet-manager/` directory
   - Excludes bootstrap manifests to prevent circular references

4. **ArgoCD Installation** (`argocd-install.yaml`)
   - Manages ArgoCD's own Helm chart
   - Contains full configuration (passwords, RBAC, ingress, health checks)
   - ArgoCD will manage its own installation via this Application

### Stage 2: Self-Management (GitOps)
Once ArgoCD is running, it syncs and sees the same manifests in Git:

1. **ArgoCD Self-Management**
   - ArgoCD detects the same `argocd-install.yaml` Application in Git
   - Takes over management of its own installation
   - No conflicts because it's the same Application definition

2. **Application Management**
   - The app-of-apps manages all other applications (`grafana.yaml`, etc.)
   - All changes go through Git as the single source of truth

## Bootstrap Flow

```
thanos-cli.py bootstrap-argocd
    │
    ├─> Apply repository-secret.yaml (Git repo connection)
    ├─> Apply fleet-manager-project.yaml (AppProject)
    ├─> Apply app-of-apps.yaml (App-of-apps)
    └─> Apply argocd-install.yaml (ArgoCD via Helm)
        │
        └─> ArgoCD deploys and becomes ready
            │
            └─> ArgoCD syncs from Git and sees the same manifests
                │
                ├─> argocd-install.yaml (ArgoCD self-management!)
                └─> app-of-apps manages other applications
                    │
                    └─> grafana.yaml, etc.
```

## Key Features

### Single Source of Truth
- All manifests are in `applications/fleet-manager/`
- Bootstrap applies the same manifests that ArgoCD will manage
- No conflicts because bootstrap and GitOps use identical Application definitions

### Circular Reference Prevention
- The app-of-apps excludes bootstrap manifests from its sync directory
- Bootstrap manifests: `repository-secret.yaml`, `fleet-manager-project.yaml`, `app-of-apps.yaml`
- This prevents ArgoCD from trying to manage its own bootstrap resources

### Self-Management
- Once bootstrapped, ArgoCD manages its own Helm installation
- Changes to `argocd-install.yaml` in Git will be automatically applied
- True GitOps: all ArgoCD changes go through the argo repository

### Finalizers
- Critical Applications have finalizers to prevent accidental deletion
- Ensures ArgoCD doesn't delete itself or its management structure

### Health Checks
- Custom health checks for Ingress resources (Traefik compatibility)
- Prevents applications from showing as "Progressing" indefinitely

## Making Changes

### To modify ArgoCD configuration:
1. Edit `applications/fleet-manager/argocd-install.yaml`
2. Commit and push to Gitea
3. ArgoCD will detect the change and sync automatically

### To add new applications:
1. Create a new Application manifest in `applications/fleet-manager/`
2. Commit and push to Gitea
3. The app-of-apps will automatically deploy it

### To modify bootstrap manifests:
1. Edit files in `applications/fleet-manager/` (repository-secret.yaml, fleet-manager-project.yaml, app-of-apps.yaml)
2. Commit and push to Gitea
3. For existing clusters, manually apply changes with `kubectl apply -f`
4. For new clusters, the bootstrap process will use the updated manifests

## Access Information

- **ArgoCD UI**: http://argocd.test
- **Username**: admin
- **Password**: admin123 (change this in `argocd-install.yaml`)
- **Git Repository**: http://gitea.test/andreas/argo.git

## Troubleshooting

### ArgoCD not syncing from Gitea
Check the repository connection:
```bash
kubectl get secret -n argocd gitea-repo
kubectl describe application -n argocd argocd-install
```

### App-of-apps not creating applications
Check if the AppProject exists:
```bash
kubectl get appproject -n argocd fleet-manager
kubectl describe application -n argocd fleet-manager-app-of-apps
```

### ArgoCD installation not syncing
Check for sync differences:
```bash
kubectl describe application -n argocd argocd-install
kubectl get application -n argocd
```

## Security Considerations

1. **Change the default admin password** in `argocd-install.yaml`
2. **Use HTTPS for Gitea** in production environments
3. **Configure Git authentication** if the repository is private
4. **Review RBAC policies** in the AppProject and ArgoCD configuration

