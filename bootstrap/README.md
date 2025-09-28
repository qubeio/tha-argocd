# ArgoCD Bootstrap Configuration

This directory contains the bootstrap configuration for setting up ArgoCD on the fleet-manager cluster.

## Bootstrap Process

1. **Install ArgoCD**: Deploy ArgoCD to the fleet-manager cluster
2. **Configure Access**: Set up ingress and authentication
3. **Register Cluster**: Add the fleet-manager cluster to ArgoCD
4. **Deploy Applications**: Deploy the fleet-manager applications

## Files

- `fleet-manager-bootstrap.yaml` - Bootstrap ArgoCD installation for fleet-manager cluster
- `README.md` - This documentation

## Usage

To bootstrap the fleet-manager cluster:

```bash
# Apply the bootstrap configuration
kubectl apply -f fleet-manager-bootstrap.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Access

Once deployed, ArgoCD will be available at:
- URL: https://argocd.test
- Username: admin
- Password: (from the secret above)
