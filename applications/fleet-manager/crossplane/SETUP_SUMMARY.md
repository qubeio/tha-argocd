# Crossplane Azure Key Vault Setup - Summary

## What Was Created

This setup enables Crossplane to manage secrets in your Azure Key Vault (`qubeio`) by reusing the same Azure credentials as External Secrets Operator.

### Files Created

```
applications/fleet-manager/
├── crossplane-config.yaml              # ArgoCD Application for Crossplane config
└── crossplane/
    ├── DEPLOYMENT.md                   # Detailed deployment guide
    ├── QUICKSTART.md                   # Quick start usage guide
    ├── README.md                       # Architecture and detailed docs
    ├── SETUP_SUMMARY.md                # This file
    ├── example-secret.yaml             # Example Secret resources
    ├── kustomization.yaml              # Kustomize configuration
    ├── provider-azure.yaml             # Azure Provider installation
    ├── provider-config.yaml            # ProviderConfig with credentials
    ├── setup-credentials.sh            # One-time credential setup script
    └── verify-setup.sh                 # Verification script
```

### Updated Files

- `applications/fleet-manager/README.md` - Added Crossplane documentation
- `README.md` (root) - Added Crossplane to applications list

## Architecture Overview

```
┌─────────────────────────────────────┐
│  External Secrets System Namespace  │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ azure-keyvault-credentials    │ │
│  │ (Source credentials)          │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
                 │
                 │ Manual script (runs once)
                 ▼
┌─────────────────────────────────────┐
│    Crossplane System Namespace      │
│                                     │
│  ┌───────────────────────────────┐ │
│  │azure-keyvault-crossplane-creds│ │
│  │ (JSON formatted)              │ │
│  └───────────────────────────────┘ │
│                │                    │
│                ▼                    │
│  ┌───────────────────────────────┐ │
│  │ ProviderConfig (default)      │ │
│  └───────────────────────────────┘ │
│                │                    │
│                ▼                    │
│  ┌───────────────────────────────┐ │
│  │ Azure Provider                │ │
│  │ (provider-azure-keyvault)     │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
                 │
                 │ Manages secrets
                 ▼
        ┌─────────────────────┐
        │   Azure Key Vault   │
        │      (qubeio)       │
        └─────────────────────┘
```

## Key Features

✅ **Credential Reuse**: Uses existing Azure credentials from External Secrets Operator  
✅ **Simple Setup**: One-time manual script to create credentials  
✅ **Lab-Friendly**: No complex automation for simple homelab use  
✅ **GitOps Ready**: All configuration in Git, managed by ArgoCD  
✅ **Wave Ordering**: Sync waves ensure proper deployment order  
✅ **Production-Ready Pattern**: Manual setup mimics production credential management outside GitOps

## Prerequisites Checklist

Before deploying, ensure:

- ✅ Crossplane is installed (via `crossplane.yaml` Application)
- ✅ External Secrets Operator is installed  
- ✅ Secret `azure-keyvault-credentials` exists in `external-secrets-system` with:
  - `clientId` - Azure service principal client ID
  - `clientSecret` - Azure service principal secret
  - `tenantId` - Azure AD tenant ID
  - `subscriptionId` - (Optional) Azure subscription ID

- ✅ Azure service principal has Key Vault permissions:
  - Secret permissions: Get, List, Set, Delete
  - Key permissions: Get, List, Create, Update (if managing keys)
  - Certificate permissions: Get, List (if managing certificates)

- ✅ Credentials copied to crossplane-system (run `./setup-credentials.sh` once)

## Quick Deployment

### Step 1: Setup Credentials (One-Time)

```bash
# Run the setup script to copy credentials
cd /home/andreas/source/repos/argo/applications/fleet-manager/crossplane
./setup-credentials.sh
```

This copies credentials from `external-secrets-system/azure-keyvault-credentials` to `crossplane-system/azure-keyvault-crossplane-creds`.

### Step 2: Deploy via ArgoCD (Recommended)

```bash
# Commit and push to Git
cd /home/andreas/source/repos/argo
git add applications/fleet-manager/crossplane/
git add applications/fleet-manager/crossplane-config.yaml
git add applications/fleet-manager/README.md
git add README.md
git commit -m "Add Crossplane Azure Key Vault integration"
git push origin main

# ArgoCD will automatically deploy
# Wait a few minutes, then verify
cd applications/fleet-manager/crossplane
./verify-setup.sh
```

### Step 3 (Alternative): Manual Testing

```bash
# First, setup credentials (if not already done)
cd /home/andreas/source/repos/argo/applications/fleet-manager/crossplane
./setup-credentials.sh

# Apply directly to cluster
cd /home/andreas/source/repos/argo/applications/fleet-manager
kubectl apply -f crossplane-config.yaml

# Wait for resources to be ready
kubectl wait --for=condition=Healthy provider/provider-azure-keyvault --timeout=300s

# Verify
cd crossplane
./verify-setup.sh
```

## Verification Steps

Run the verification script:

```bash
cd /home/andreas/source/repos/argo/applications/fleet-manager/crossplane
./verify-setup.sh
```

This checks:
- ✅ Crossplane installation
- ✅ Azure provider health
- ✅ Source credentials exist
- ✅ Credentials synced to crossplane-system
- ✅ ProviderConfig created
- ✅ ArgoCD Application status

## Test Secret Creation

Create a test secret:

```bash
# Get your Azure details
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RESOURCE_GROUP=$(az keyvault show --name qubeio --query resourceGroup -o tsv)

# Create a test secret
cat <<EOF | kubectl apply -f -
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: test-crossplane-secret
  namespace: default
spec:
  forProvider:
    keyVaultId: /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/qubeio
    value: "Hello from Crossplane!"
    contentType: "text/plain"
  providerConfigRef:
    name: default
EOF

# Check status
kubectl get secrets.keyvault.azure.upbound.io test-crossplane-secret
kubectl describe secret.keyvault.azure.upbound.io test-crossplane-secret

# Verify in Azure
az keyvault secret show --vault-name qubeio --name test-crossplane-secret

# Clean up
kubectl delete secret.keyvault.azure.upbound.io test-crossplane-secret
```

## Usage Examples

### Write a Simple Secret

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: my-app-secret
spec:
  forProvider:
    keyVaultId: /subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.KeyVault/vaults/qubeio
    value: "my-secret-value"
  providerConfigRef:
    name: default
```

### Sync from Kubernetes Secret

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: synced-secret
spec:
  forProvider:
    keyVaultId: /subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.KeyVault/vaults/qubeio
    valueSecretRef:
      name: k8s-secret-name
      namespace: default
      key: secret-key
  providerConfigRef:
    name: default
```

## Documentation

- **README.md** - Complete architecture, components, and reference
- **QUICKSTART.md** - Quick start guide with common patterns
- **DEPLOYMENT.md** - Detailed deployment guide and troubleshooting
- **example-secret.yaml** - Example Secret resources

## Common Commands

```bash
# Check provider status
kubectl get providers -n crossplane-system

# Check ProviderConfig
kubectl get providerconfigs

# List all managed secrets
kubectl get secrets.keyvault.azure.upbound.io -A

# View provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault

# Verify credentials exist
kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system

# View credentials (formatted)
kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system \
  -o jsonpath='{.data.credentials}' | base64 -d | jq

# Get Azure Key Vault ID
az keyvault show --name qubeio --query id -o tsv
```

## Troubleshooting

### Provider Not Healthy

```bash
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault
kubectl describe provider provider-azure-keyvault
```

### Credentials Not Found

```bash
# Run the setup script
cd applications/fleet-manager/crossplane
./setup-credentials.sh
```

### Secret Creation Failed

```bash
kubectl describe secret.keyvault.azure.upbound.io <secret-name>
# Check Events and Conditions sections
```

## Next Steps

1. ✅ Run `./setup-credentials.sh` to create credentials (one-time)
2. ✅ Deploy via ArgoCD or manually
3. ✅ Run `./verify-setup.sh` to confirm everything is working
4. ✅ Create a test secret
5. 📖 Read QUICKSTART.md for usage patterns
6. 📖 Read README.md for detailed architecture
7. 🚀 Start managing your Azure Key Vault secrets with Crossplane!

## Support Resources

- **Crossplane Docs**: https://docs.crossplane.io/
- **Azure Provider**: https://marketplace.upbound.io/providers/upbound/provider-azure-keyvault/
- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Azure Key Vault**: https://docs.microsoft.com/en-us/azure/key-vault/

## Security Notes

1. **Credentials**: Stored as Kubernetes secrets. This manual approach is suitable for lab environments. In production, consider using External Secrets Operator, Sealed Secrets, or Azure Workload Identity.

2. **Manual Setup**: Credentials are created once outside of GitOps, which is the recommended pattern even for production.

3. **Secret Deletion**: When you delete a Secret resource from Kubernetes, it will also be deleted from Azure Key Vault (unless using `managementPolicies: ["Observe"]`).

4. **Audit**: Enable Azure Key Vault diagnostic logging to track all operations.

5. **Access Policies**: Regularly review and audit service principal permissions on the Key Vault.

## Cleanup

To remove Crossplane configuration only (keeps Crossplane core):

```bash
kubectl delete application crossplane-config -n argocd
```

To remove everything:

```bash
kubectl delete application crossplane-config -n argocd
kubectl delete application crossplane -n argocd
```

---

**Setup completed!** 🎉

You now have Crossplane configured to manage Azure Key Vault secrets using your existing Azure credentials.

