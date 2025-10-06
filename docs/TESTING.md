# Testing the Bootstrap Process

This document provides step-by-step instructions for testing the ArgoCD bootstrap and self-management setup.

## Prerequisites

Before testing, ensure:

1. Docker is running
2. `kind` is installed
3. `kubectl` is installed
4. `helm` is installed
5. You're in the thanos repository directory

## Full Bootstrap Test

### 1. Clean Environment

Start with a clean slate:

```bash
cd /home/andreas/source/repos/thanos

# Destroy any existing infrastructure
python thanos-cli.py destroy

# Verify cleanup
docker ps
kind get clusters
```

### 2. Provision Infrastructure

Create the base infrastructure:

```bash
# This creates Docker network, Kind cluster, MetalLB, and Traefik
python thanos-cli.py provision-infrastructure

# Verify cluster is ready
kubectl get nodes
kubectl get pods -n kube-system
kubectl get pods -n metallb-system
kubectl get pods -n traefik
```

Expected output:

- 2 nodes (control-plane and worker) in Ready state
- All system pods Running
- MetalLB controller and speaker running
- Traefik pods running

### 3. Set Up Base Services

Start Gitea and other services:

```bash
# This starts Gitea, CoreDNS, and Tailscale router
python thanos-cli.py setup-base-services

# Verify services
docker ps
dig @10.100.200.10 -p 53 gitea.test
```

Expected output:

- Gitea accessible at http://gitea.test
- DNS resolving correctly

### 4. Prepare Git Repository

Ensure the argo repository is pushed to Gitea:

```bash
cd /home/andreas/source/repos/argo

# Add the Gitea remote if not already added
git remote add github https://github.com/qubeio/tha-argocd.git

# Push the repository
git push gitea main
```

### 5. Bootstrap ArgoCD

Now bootstrap ArgoCD with GitOps:

```bash
cd /home/andreas/source/repos/thanos

# This installs ArgoCD and connects it to the GitOps repo
python thanos-cli.py bootstrap-argocd

# Wait for ArgoCD to be ready (may take 1-2 minutes)
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
```

Expected output:

- ArgoCD installed
- gitops-bootstrap Application created
- Success message with access information

### 6. Verify Bootstrap Applications

Check that the bootstrap applications are created:

```bash
# List all applications
kubectl get applications -n argocd

# Should see:
# - fleet-manager-bootstrap (manages ArgoCD Helm chart)
# - gitops-bootstrap (manages bootstrap manifests)
```

### 7. Wait for GitOps Sync

The gitops-bootstrap Application will sync and create additional resources:

```bash
# Watch the sync process
watch kubectl get applications -n argocd

# After sync completes, you should see:
# - gitops-bootstrap (Synced)
# - fleet-manager-app-of-apps (Synced)
# - argocd-install (Synced)
```

This may take 1-2 minutes as ArgoCD:

1. Clones the repository
2. Creates the AppProject
3. Creates the app-of-apps
4. Syncs all applications

### 8. Verify Repository Connection

Check that ArgoCD connected to Gitea:

```bash
# Check repository secret
kubectl get secret -n argocd github-repo -o yaml

# Check ArgoCD can reach the repository
kubectl logs -n argocd deployment/argocd-repo-server | grep gitea
```

### 9. Verify AppProject

Check the fleet-manager project was created:

```bash
kubectl get appproject -n argocd fleet-manager -o yaml
```

Expected output:

- Project exists
- Source repos include Gitea and Helm repos
- Destinations allow all namespaces

### 10. Verify App-of-Apps

Check the app-of-apps Application:

```bash
kubectl describe application -n argocd fleet-manager-app-of-apps

# Check sync status
kubectl get application -n argocd fleet-manager-app-of-apps -o jsonpath='{.status.sync.status}'
```

Expected output: `Synced`

### 11. Verify ArgoCD Self-Management

Check that ArgoCD is managing itself:

```bash
# Check the argocd-install Application
kubectl get application -n argocd argocd-install

# Verify it's synced and healthy
kubectl describe application -n argocd argocd-install
```

Expected output:

- Application is Synced
- Health status is Healthy
- Source points to Helm chart
- Configuration matches argocd-install.yaml

### 12. Access ArgoCD UI

Open ArgoCD in your browser:

```bash
# Get the admin password (should be admin123)
kubectl -n argocd get secret argocd-secret \
  -o jsonpath='{.data.admin\.password}' | base64 -d

# Access the UI
echo "ArgoCD UI: http://argocd.test"
echo "Username: admin"
echo "Password: admin123"
```

In the UI, verify:

- All Applications are visible
- Applications are Synced and Healthy
- Repository connection is working
- The topology view shows relationships

## Testing Self-Management

### Test 1: Update ArgoCD Configuration

Test that ArgoCD can update itself:

```bash
cd /home/andreas/source/repos/argo

# Edit the ArgoCD configuration
# For example, change the RBAC policy
vim applications/fleet-manager/argocd-install.yaml

# Add a comment or make a small change to configs.rbac.policy.csv

# Commit and push
git add applications/fleet-manager/argocd-install.yaml
git commit -m "Test: Update ArgoCD RBAC"
git push gitea main

# Watch ArgoCD detect and sync the change
kubectl get application -n argocd argocd-install -w

# Or watch in the UI
```

Expected behavior:

- ArgoCD detects the change within ~3 minutes (default sync interval)
- Application shows OutOfSync
- Application automatically syncs
- Changes are applied to ArgoCD

### Test 2: Add a New Application

Test the app-of-apps pattern:

```bash
cd /home/andreas/source/repos/argo

# Create a simple test application
cat > applications/fleet-manager/test-nginx.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-nginx
  namespace: argocd
spec:
  project: fleet-manager
  source:
    repoURL: https://charts.bitnami.com/bitnami
    targetRevision: 15.0.0
    chart: nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: test-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Commit and push
git add applications/fleet-manager/test-nginx.yaml
git commit -m "Test: Add nginx application"
git push gitea main

# Watch for the new Application to appear
watch kubectl get applications -n argocd
```

Expected behavior:

- The app-of-apps detects the new file
- A new Application `test-nginx` is created
- The nginx Helm chart is deployed
- A new namespace `test-nginx` is created

Cleanup:

```bash
# Remove the test application
rm applications/fleet-manager/test-nginx.yaml
git add applications/fleet-manager/test-nginx.yaml
git commit -m "Test: Remove nginx application"
git push gitea main

# The namespace and resources will be automatically pruned
```

### Test 3: Modify Bootstrap Manifests

Test that bootstrap manifests can be updated:

```bash
cd /home/andreas/source/repos/argo

# Edit a bootstrap manifest
vim bootstrap-manifests/02-project.yaml

# Add a new source repository to the sourceRepos list
# For example: - 'https://charts.jetstack.io'

# Commit and push
git add bootstrap-manifests/02-project.yaml
git commit -m "Test: Update AppProject"
git push gitea main

# Watch the gitops-bootstrap Application
kubectl describe application -n argocd gitops-bootstrap
```

Expected behavior:

- gitops-bootstrap detects the change
- The AppProject is updated
- No disruption to existing applications

## Troubleshooting

### Applications Stuck in Progressing

```bash
# Check application status
kubectl describe application -n argocd <app-name>

# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Repository Connection Failed

```bash
# Check repository secret
kubectl get secret -n argocd github-repo -o yaml

# Check if Gitea is accessible from the cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- \
  wget -O- https://github.com/qubeio/tha-argocd.git/info/refs?service=git-upload-pack

# Check ArgoCD repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### ArgoCD Not Syncing

```bash
# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller | grep ERROR

# Force a refresh
kubectl patch application -n argocd <app-name> \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge

# Or use the CLI
argocd app sync <app-name>
```

### Circular Reference Detected

This shouldn't happen if configured correctly, but if it does:

```bash
# Check the app-of-apps Application
kubectl get application -n argocd fleet-manager-app-of-apps -o yaml

# Verify the exclude pattern is present
# Should see: exclude: "app-of-apps.yaml"
```

## Success Criteria

The bootstrap is successful if:

1. ✅ ArgoCD is running and accessible at http://argocd.test
2. ✅ All bootstrap Applications are Synced and Healthy
3. ✅ The gitops-bootstrap Application created repository, project, and app-of-apps
4. ✅ The app-of-apps created the argocd-install Application
5. ✅ ArgoCD is managing its own Helm installation
6. ✅ Changes to Git are automatically synced to the cluster
7. ✅ New applications can be added by committing to Git

## Cleanup

To clean up after testing:

```bash
cd /home/andreas/source/repos/thanos

# Destroy everything
python thanos-cli.py destroy

# Verify cleanup
docker ps
kind get clusters
```
