# Vcluster Platforms

This directory contains vcluster definitions and their associated ArgoCD Applications for managing virtual Kubernetes clusters within the fleet-manager cluster.

## Directory Structure

Each vcluster consists of two files:
- `<name>.yaml` - Vcluster definition (deploys the vcluster itself)
- `<name>-apps.yaml` - ArgoCD Application that deploys workloads into the vcluster

```
platforms/
├── nprod1.yaml          # Non-production vcluster instance
├── nprod1-apps.yaml     # Applications for nprod1
├── prod1.yaml           # Production vcluster instance
└── prod1-apps.yaml      # Applications for prod1
```

## Naming Conventions

Use the following naming patterns for vclusters:
- **Non-production**: `nprod1`, `nprod2`, `nprod3`, etc.
- **Production**: `prod1`, `prod2`, `prod3`, etc.

## How Vclusters Work

Vclusters are fully functional Kubernetes clusters running as pods inside the fleet-manager cluster. Each vcluster:
- Runs in its own namespace: `vcluster-<name>`
- Has its own control plane (K3s)
- Shares the underlying node resources with the host cluster
- Provides isolation between different environments
- Can be managed by the same ArgoCD instance as the host cluster

## Adding a New Vcluster

### 1. Create Vcluster Definition

Create `<name>.yaml` in this directory:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vcluster-<name>
  namespace: argocd
spec:
  project: fleet-manager
  source:
    repoURL: https://charts.loft.sh
    targetRevision: 0.20.0
    chart: vcluster
    helm:
      releaseName: <name>
      valuesObject:
        sync:
          nodes:
            enabled: true
          persistentvolumes:
            enabled: true
        coredns:
          enabled: true
        service:
          type: ClusterIP
        vcluster:
          image: rancher/k3s:v1.28.5-k3s1
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 128Mi
        storage:
          size: 5Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: vcluster-<name>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 2. Create Application Directory

Create a directory in `applications/<name>/` for the vcluster's workloads:

```bash
mkdir -p ../applications/<name>
```

Add Kubernetes manifests for applications that should run in the vcluster.

### 3. Create Apps Application

Create `<name>-apps.yaml` in this directory:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <name>-apps
  namespace: argocd
spec:
  project: fleet-manager
  source:
    repoURL: https://github.com/qubeio/tha-argocd.git
    targetRevision: HEAD
    path: applications/<name>
    directory:
      include: "*.yaml"
  destination:
    name: vcluster-<name>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 10
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 10m
```

### 4. Commit and Push

```bash
git add platforms/<name>.yaml platforms/<name>-apps.yaml applications/<name>/
git commit -m "Add vcluster <name>"
git push
```

ArgoCD will automatically detect and deploy the new vcluster and its applications.

## Bootstrap Process

1. **Vcluster Deployment**: The `vclusters` Application in fleet-manager monitors this directory and deploys all vcluster definitions
2. **Vcluster Startup**: Each vcluster starts as a set of pods in its dedicated namespace
3. **Cluster Registration**: Vclusters need to be manually registered with ArgoCD initially (see below)
4. **Application Deployment**: Once registered, the `*-apps.yaml` Applications deploy workloads into the vclusters

## Registering Vclusters with ArgoCD

After a vcluster is created, you need to register it with ArgoCD so applications can be deployed to it:

### Method 1: Using vcluster CLI (Recommended)

```bash
# Install vcluster CLI (if not already installed)
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"
chmod +x vcluster
sudo mv vcluster /usr/local/bin/

# Connect to the vcluster
vcluster connect <name> -n vcluster-<name>

# Register with ArgoCD
argocd cluster add vcluster_<name>_vcluster-<name>_fleet-manager --name vcluster-<name>

# Disconnect
vcluster disconnect
```

### Method 2: Manual Registration

```bash
# Get vcluster kubeconfig
kubectl get secret vc-<name> -n vcluster-<name> -o jsonpath='{.data.config}' | base64 -d > /tmp/<name>-kubeconfig

# Register with ArgoCD
argocd cluster add <name> --kubeconfig /tmp/<name>-kubeconfig --name vcluster-<name>

# Clean up
rm /tmp/<name>-kubeconfig
```

## Accessing Vclusters

### Using kubectl

```bash
# Connect to vcluster (creates kubeconfig context)
vcluster connect <name> -n vcluster-<name>

# Use kubectl normally
kubectl get pods -A

# Disconnect
vcluster disconnect
```

### Using ArgoCD UI

1. Navigate to http://argocd.test
2. Go to Settings → Clusters
3. You should see `vcluster-<name>` in the cluster list
4. Applications targeting this cluster will deploy there

## Managing Applications in Vclusters

Add Kubernetes manifests to `applications/<name>/` directory:

```bash
# Example: Add a new application to nprod1
cat > applications/nprod1/myapp.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

git add applications/nprod1/myapp.yaml
git commit -m "Add myapp to nprod1"
git push
```

ArgoCD will automatically sync the new application to the vcluster.

## Troubleshooting

### Vcluster pod is not starting

```bash
# Check vcluster pod status
kubectl get pods -n vcluster-<name>

# Check pod logs
kubectl logs -n vcluster-<name> -l app=vcluster

# Check ArgoCD Application status
argocd app get vcluster-<name>
```

### Applications not deploying to vcluster

1. Verify vcluster is registered:
   ```bash
   argocd cluster list | grep vcluster-<name>
   ```

2. Check Application sync status:
   ```bash
   argocd app get <name>-apps
   ```

3. Verify the destination cluster name matches:
   ```bash
   # In <name>-apps.yaml, the destination.name should match 
   # the registered cluster name
   ```

### Vcluster is using too many resources

Edit the vcluster definition in `<name>.yaml` and adjust resource limits:

```yaml
resources:
  limits:
    cpu: 500m      # Reduce from 1000m
    memory: 512Mi  # Reduce from 1Gi
  requests:
    cpu: 50m       # Reduce from 100m
    memory: 64Mi   # Reduce from 128Mi
```

## Removing a Vcluster

1. Delete the vcluster files:
   ```bash
   git rm platforms/<name>.yaml platforms/<name>-apps.yaml
   git rm -r applications/<name>/
   git commit -m "Remove vcluster <name>"
   git push
   ```

2. ArgoCD will automatically remove the vcluster and its applications

3. Unregister from ArgoCD:
   ```bash
   argocd cluster rm vcluster-<name>
   ```

## Best Practices

1. **Resource Limits**: Always set appropriate resource limits to prevent vclusters from consuming too many host resources

2. **Naming Convention**: Follow the `nprod`/`prod` naming convention for consistency

3. **Application Organization**: Keep vcluster-specific applications in their dedicated `applications/<name>/` directory

4. **Testing**: Test changes in `nprod` vclusters before applying to `prod` vclusters

5. **Monitoring**: Monitor vcluster resource usage in the host cluster:
   ```bash
   kubectl top pods -n vcluster-<name>
   ```

6. **IPAM**: If vclusters need external IPs, consult and update `IPAM.md` in the thanos repository

## Future Enhancements

- ApplicationSets for deploying common infrastructure to all vclusters
- Automated vcluster registration with ArgoCD
- Resource quotas and limit ranges per vcluster type
- Automated IPAM integration
- Vcluster templates for different use cases (dev, staging, prod)

