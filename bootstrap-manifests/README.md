# Bootstrap Manifests

This directory contains the initial manifests that connect ArgoCD to the GitOps repository and set up the app-of-apps pattern.

## Purpose

These manifests are applied by the `gitops-bootstrap` Application created during the initial bootstrap process. They establish the foundation for ArgoCD to manage itself via GitOps.

## Files

### 01-repository.yaml
Creates a Secret that configures the connection to the Gitea repository.

- **Type**: Repository credential secret
- **Purpose**: Allows ArgoCD to clone from `http://gitea.test/andreas/argo.git`
- **Insecure**: Configured for HTTP (internal network only)

### 02-project.yaml
Creates the `fleet-manager` AppProject.

- **Purpose**: Defines permissions and allowed resources for fleet-manager applications
- **Source Repos**: Helm charts and the Gitea repository
- **Destinations**: All namespaces on the local cluster
- **Permissions**: Allows all resources (suitable for admin cluster)

### 03-app-of-apps.yaml
Creates the main Application that manages all other applications.

- **Purpose**: Implements the app-of-apps pattern
- **Source Path**: `applications/fleet-manager/`
- **Excludes**: Itself (`app-of-apps.yaml`) to prevent circular references
- **Auto-sync**: Enabled with pruning and self-heal

## Modification Guidelines

### Adding a New Repository
Edit `01-repository.yaml` or create a new repository secret following the same pattern:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: another-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/your-org/your-repo.git
  name: another-repo
```

### Modifying Project Permissions
Edit `02-project.yaml` to:
- Add more source repositories
- Restrict resource types
- Change destination clusters
- Add more granular RBAC

### Changing App-of-Apps Behavior
Edit `03-app-of-apps.yaml` to:
- Point to a different directory
- Change sync policies
- Modify include/exclude patterns
- Add sync waves or hooks

## Application Order

The files are prefixed with numbers (`01-`, `02-`, `03-`) to suggest a logical ordering, but ArgoCD applies them in parallel. The dependencies work because:

1. The repository secret is needed before Applications can sync
2. The AppProject must exist before Applications reference it
3. The app-of-apps references the project and repository

ArgoCD's reconciliation loop will retry until dependencies are satisfied.

## Warning

**Do not delete these manifests** unless you're certain about the impact:
- Deleting `01-repository.yaml` will break ArgoCD's connection to Git
- Deleting `02-project.yaml` will prevent Applications from being created
- Deleting `03-app-of-apps.yaml` will stop automatic application management

If you need to make breaking changes, ensure you have a backup plan to restore the bootstrap process.

