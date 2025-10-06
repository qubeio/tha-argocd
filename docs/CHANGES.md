# Changes Made for ArgoCD Self-Management

## Summary

This document describes the changes made to enable ArgoCD to manage itself via GitOps from the GitHub repository at `https://github.com/qubeio/tha-argocd.git`.

## Problems Identified

1. **No GitOps Connection**: The bootstrap process installed ArgoCD but didn't connect it to the Git repository
2. **Incomplete ArgoCD Config**: The `argocd-install.yaml` was missing critical configuration (passwords, RBAC, etc.)
3. **Circular Reference Risk**: The app-of-apps would include itself, causing potential issues
4. **Missing Bootstrap Chain**: No mechanism to apply repository secrets and projects after initial installation

## Changes Made

### 1. New Bootstrap Application (thanos/bootstrap/)

**File: `thanos/bootstrap/gitops-bootstrap.yaml`** (NEW)
- Creates an Application that syncs from `bootstrap-manifests/` directory in the argo repo
- Establishes the connection between ArgoCD and the GitOps repository
- Applied automatically by `thanos-cli.py` during bootstrap

### 2. Bootstrap Manifests Directory (argo/bootstrap-manifests/)

Created a new directory with three core manifests:

**File: `bootstrap-manifests/01-repository.yaml`** (NEW)
- Creates Secret for Gitea repository connection
- Enables ArgoCD to clone from `https://github.com/qubeio/tha-argocd.git`
- Includes `insecure: "true"` flag for HTTP Git access

**File: `bootstrap-manifests/02-project.yaml`** (NEW)
- Creates the `fleet-manager` AppProject
- Defines allowed source repositories (Helm charts, Gitea)
- Sets permissions for all resources (admin cluster)

**File: `bootstrap-manifests/03-app-of-apps.yaml`** (NEW)
- Creates the main Application that manages other applications
- Points to `applications/fleet-manager/` directory
- **Excludes `app-of-apps.yaml`** to prevent circular references
- Enables automated sync with pruning and self-heal

### 3. Updated ArgoCD Installation Manifest

**File: `argo/applications/fleet-manager/argocd-install.yaml`** (UPDATED)

Changes:
- Changed from `parameters` to `valuesObject` for better Helm value structure
- Added complete configuration matching bootstrap values:
  - Admin password (bcrypt hash for `admin123`)
  - RBAC policies
  - Insecure mode for HTTP
  - Ingress configuration
  - URL configuration
- Changed project from `default` to `fleet-manager`
- Added finalizers to prevent accidental deletion
- Added `ServerSideApply=true` for better resource management
- Added retry logic with exponential backoff
- Added `ignoreDifferences` for ArgoCD-managed secrets
- Changed repo URL to use `https://argoproj.github.io/argo-helm` (official Helm repo)

### 4. Removed Redundant File

**File: `argo/applications/fleet-manager/app-of-apps.yaml`** (DELETED)
- Removed to prevent circular reference
- Functionality replaced by `bootstrap-manifests/03-app-of-apps.yaml`
- The app-of-apps is now managed outside the directory it syncs

### 5. Updated thanos-cli.py

**File: `thanos/thanos-cli.py`** (UPDATED)

Changes in `bootstrap_argocd()` function:
- Added `gitops-bootstrap.yaml` to the list of bootstrap applications
- Updated success message to reflect GitOps self-management
- Changed password display from dynamic to fixed `admin123`

### 6. Documentation

Created comprehensive documentation:

**File: `argo/BOOTSTRAP.md`** (NEW)
- Detailed architecture explanation
- Three-stage bootstrap process
- Bootstrap flow diagram
- Key features (circular reference prevention, self-management)
- Making changes guide
- Troubleshooting section
- Security considerations

**File: `argo/bootstrap-manifests/README.md`** (NEW)
- Purpose of each bootstrap manifest
- Modification guidelines
- Application order explanation
- Warnings about deletion

**File: `argo/TESTING.md`** (NEW)
- Step-by-step testing instructions
- Full bootstrap test procedure
- Self-management tests
- Troubleshooting commands
- Success criteria checklist

**File: `argo/README.md`** (UPDATED)
- Updated repository structure
- Corrected API server IP (10.100.200.2)
- Added three-stage bootstrap process
- Updated making changes section
- Added directory details and key features

**File: `argo/CHANGES.md`** (NEW - this file)
- Summary of all changes made

### 7. Fixed IP Address

**File: `argo/clusters/fleet-manager.yaml`** (UPDATED)
- Changed server IP from `10.100.0.2` to `10.100.200.2`
- Matches the actual IP assigned in `thanos-cli.py`

## Architecture Overview

```
Bootstrap Chain:
┌─────────────────────────────────────────────────────────────┐
│ thanos-cli.py bootstrap-argocd                              │
│ ├─> Helm install ArgoCD                                     │
│ ├─> Apply fleet-manager-bootstrap.yaml                      │
│ │   └─> Manages ArgoCD Helm installation                    │
│ └─> Apply gitops-bootstrap.yaml (NEW)                       │
│     └─> Syncs bootstrap-manifests/ from Git                 │
│         ├─> 01-repository.yaml (Git connection)             │
│         ├─> 02-project.yaml (AppProject)                    │
│         └─> 03-app-of-apps.yaml (NEW)                       │
│             └─> Syncs applications/fleet-manager/           │
│                 └─> argocd-install.yaml (UPDATED)           │
│                     └─> ArgoCD manages itself! ✅           │
└─────────────────────────────────────────────────────────────┘
```

## Key Improvements

1. **Complete GitOps Integration**: ArgoCD now fully manages itself from Git
2. **Circular Reference Prevention**: Smart exclusions prevent infinite loops
3. **Automated Sync**: All changes in Git are automatically applied
4. **Proper Configuration**: ArgoCD config matches bootstrap values
5. **Better Organization**: Clear separation of bootstrap vs application manifests
6. **Comprehensive Documentation**: Easy to understand and troubleshoot
7. **Safe Deletions**: Finalizers prevent accidental removal of critical resources

## Testing

See [TESTING.md](./TESTING.md) for complete testing instructions.

Quick verification after bootstrap:
```bash
# Check all applications are created
kubectl get applications -n argocd

# Expected output:
# NAME                          SYNC STATUS   HEALTH STATUS
# fleet-manager-bootstrap       Synced        Healthy
# gitops-bootstrap             Synced        Healthy  
# fleet-manager-app-of-apps    Synced        Healthy
# argocd-install               Synced        Healthy
```

## Migration Notes

If you already have ArgoCD running:

1. **Back up existing configuration**:
   ```bash
   kubectl get applications -n argocd -o yaml > backup-apps.yaml
   kubectl get appproject -n argocd -o yaml > backup-projects.yaml
   ```

2. **Apply the gitops-bootstrap Application**:
   ```bash
   kubectl apply -f /home/andreas/source/repos/thanos/bootstrap/gitops-bootstrap.yaml
   ```

3. **Wait for sync** (2-3 minutes)

4. **Verify** all applications are healthy:
   ```bash
   kubectl get applications -n argocd
   ```

## Security Notes

⚠️ **Important**: The default admin password is `admin123`. Change this in production:

1. Edit `applications/fleet-manager/argocd-install.yaml`
2. Generate a new bcrypt hash:
   ```bash
   htpasswd -nbBC 10 "" your-new-password | tr -d ':\n' | sed 's/$2y/$2a/'
   ```
3. Replace the hash in the file
4. Commit and push to Git
5. ArgoCD will sync and update the password

## Rollback Plan

If something goes wrong:

1. **Delete the gitops-bootstrap Application**:
   ```bash
   kubectl delete application -n argocd gitops-bootstrap
   ```

2. **Restore from backup**:
   ```bash
   kubectl apply -f backup-apps.yaml
   kubectl apply -f backup-projects.yaml
   ```

3. **Or destroy and re-bootstrap**:
   ```bash
   cd /home/andreas/source/repos/thanos
   python thanos-cli.py destroy
   python thanos-cli.py provision-infrastructure
   python thanos-cli.py bootstrap-argocd
   ```

## Next Steps

1. **Test the bootstrap process** using [TESTING.md](./TESTING.md)
2. **Add more applications** to `applications/fleet-manager/`
3. **Set up CI/CD pipelines** to validate manifests before merge
4. **Configure notifications** for ArgoCD sync events
5. **Implement RBAC** for multi-team access

## Questions?

See:
- [BOOTSTRAP.md](./BOOTSTRAP.md) - Detailed architecture
- [TESTING.md](./TESTING.md) - Testing procedures
- [README.md](./README.md) - General overview

