# ArgoCD Self-Management Bootstrap

This document explains how ArgoCD is configured to manage itself via GitOps.

## Architecture

The bootstrap process follows a multi-stage approach:

### Stage 1: Initial Installation (thanos-cli.py)
The `thanos-cli.py` script performs the initial ArgoCD installation:

1. **Install ArgoCD via Helm** (`bootstrap/argocd-bootstrap-values.yaml`)
   - Sets up basic ArgoCD configuration
   - Configures ingress, authentication, and RBAC
   - Creates the ArgoCD namespace and core components

2. **Apply Fleet Manager Bootstrap** (`bootstrap/fleet-manager-bootstrap.yaml`)
   - Creates an Application that manages the ArgoCD Helm installation
   - Ensures ArgoCD configuration is version-controlled

3. **Apply GitOps Bootstrap** (`bootstrap/gitops-bootstrap.yaml`)
   - Creates an Application that syncs from the `bootstrap-manifests/` directory
   - This Application sets up the GitOps repository connection

### Stage 2: GitOps Repository Connection (bootstrap-manifests/)
The gitops-bootstrap Application syncs the following manifests:

1. **Repository Secret** (`01-repository.yaml`)
   - Configures connection to Gitea repository
   - URL: `http://gitea.test/andreas/argo.git`
   - Enables ArgoCD to pull from the GitOps repo

2. **AppProject** (`02-project.yaml`)
   - Creates the `fleet-manager` project
   - Defines allowed source repositories (Helm charts, Gitea)
   - Sets up RBAC and destination permissions

3. **App-of-Apps** (`03-app-of-apps.yaml`)
   - Creates the main Application that manages all other applications
   - Points to `applications/fleet-manager/` directory
   - Excludes itself to prevent circular references

### Stage 3: Self-Management (applications/fleet-manager/)
Once the app-of-apps is created, it manages:

1. **ArgoCD Installation** (`argocd-install.yaml`)
   - Manages ArgoCD's own Helm chart
   - Contains full configuration (passwords, RBAC, ingress)
   - ArgoCD now manages its own installation!

2. **Other Applications** (`grafana.yaml`, etc.)
   - Additional applications for the fleet-manager cluster
   - All managed via GitOps

## Bootstrap Flow

```
thanos-cli.py
    │
    ├─> Helm install ArgoCD (initial deployment)
    │
    ├─> Apply fleet-manager-bootstrap.yaml
    │   └─> Creates Application to manage ArgoCD Helm chart
    │
    └─> Apply gitops-bootstrap.yaml
        └─> Creates Application to sync bootstrap-manifests/
            │
            ├─> 01-repository.yaml (Git repo connection)
            ├─> 02-project.yaml (AppProject)
            └─> 03-app-of-apps.yaml
                └─> Syncs applications/fleet-manager/
                    │
                    ├─> argocd-install.yaml (ArgoCD self-management!)
                    └─> Other applications...
```

## Key Features

### Circular Reference Prevention
- The app-of-apps excludes `app-of-apps.yaml` from its sync directory
- This prevents ArgoCD from trying to manage the app-of-apps Application recursively

### Self-Management
- Once bootstrapped, ArgoCD manages its own Helm installation
- Changes to `argocd-install.yaml` in Git will be automatically applied
- The initial bootstrap Applications remain to ensure stability

### Finalizers
- Critical Applications have finalizers to prevent accidental deletion
- Ensures ArgoCD doesn't delete itself or its management structure

### Ignore Differences
- The `argocd-install.yaml` ignores differences in ArgoCD's internal secrets
- Prevents sync conflicts with secrets ArgoCD manages itself

## Making Changes

### To modify ArgoCD configuration:
1. Edit `applications/fleet-manager/argocd-install.yaml`
2. Commit and push to Gitea
3. ArgoCD will detect the change and sync automatically

### To add new applications:
1. Create a new Application manifest in `applications/fleet-manager/`
2. Commit and push to Gitea
3. The app-of-apps will automatically deploy it

### To modify bootstrap behavior:
1. Edit files in `bootstrap-manifests/`
2. Commit and push to Gitea
3. The gitops-bootstrap Application will sync the changes

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
kubectl describe application -n argocd gitops-bootstrap
```

### App-of-apps not creating applications
Check if the AppProject exists:
```bash
kubectl get appproject -n argocd fleet-manager
```

### ArgoCD installation not syncing
Check for sync differences:
```bash
kubectl describe application -n argocd argocd-install
```

## Security Considerations

1. **Change the default admin password** in `argocd-install.yaml`
2. **Use HTTPS for Gitea** in production environments
3. **Configure Git authentication** if the repository is private
4. **Review RBAC policies** in the AppProject and ArgoCD configuration

