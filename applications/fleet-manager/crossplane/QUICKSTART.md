# Crossplane Azure Key Vault - Quick Start

This guide walks you through getting started with Crossplane to manage Azure Key Vault secrets.

## Prerequisites

Before you begin, ensure:

1. ✅ Crossplane is installed (`crossplane` Application in ArgoCD)
2. ✅ Azure credentials exist in `external-secrets-system/azure-keyvault-credentials`
3. ✅ You have access to the `qubeio` Azure Key Vault

## Step 1: Deploy Crossplane Configuration

The `crossplane-config` Application in ArgoCD will automatically deploy:
- Azure Key Vault provider
- Credential synchronization job
- ProviderConfig with your Azure credentials

Wait for all components to be ready:

```bash
# Check provider status
kubectl get providers -n crossplane-system

# Should show:
# NAME                         INSTALLED   HEALTHY   AGE
# provider-azure-keyvault      True        True      2m

# Check ProviderConfig
kubectl get providerconfigs

# Should show:
# NAME      AGE
# default   2m
```

## Step 2: Create Your First Secret

Create a simple secret in Azure Key Vault:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: my-first-secret
  namespace: default
spec:
  forProvider:
    keyVaultId: /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/qubeio
    value: "Hello from Crossplane!"
    contentType: "text/plain"
  providerConfigRef:
    name: default
EOF
```

**Note**: Replace `YOUR_SUBSCRIPTION_ID` and `YOUR_RESOURCE_GROUP` with your actual values.

## Step 3: Verify the Secret

Check the secret status in Kubernetes:

```bash
kubectl get secrets.keyvault.azure.upbound.io
kubectl describe secret.keyvault.azure.upbound.io my-first-secret
```

Look for `Ready: True` in the status.

Verify in Azure:

```bash
az keyvault secret show --vault-name qubeio --name my-first-secret
```

Or check in the Azure Portal: https://portal.azure.com

## Step 4: Sync a Kubernetes Secret to Key Vault

Create a Kubernetes secret and sync it to Azure Key Vault:

```bash
# Create a Kubernetes secret
kubectl create secret generic app-credentials \
  --from-literal=database-password='super-secret-password' \
  --from-literal=api-key='abc123xyz'

# Create Crossplane resources to sync to Key Vault
cat <<EOF | kubectl apply -f -
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: app-db-password
spec:
  forProvider:
    keyVaultId: /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/qubeio
    valueSecretRef:
      name: app-credentials
      namespace: default
      key: database-password
  providerConfigRef:
    name: default
---
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: app-api-key
spec:
  forProvider:
    keyVaultId: /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/qubeio
    valueSecretRef:
      name: app-credentials
      namespace: default
      key: api-key
  providerConfigRef:
    name: default
EOF
```

## Step 5: Update a Secret

To update a secret value, modify the resource:

```bash
kubectl patch secret.keyvault.azure.upbound.io my-first-secret \
  --type merge \
  -p '{"spec":{"forProvider":{"value":"Updated value from Crossplane!"}}}'
```

The change will automatically sync to Azure Key Vault.

## Step 6: Delete a Secret

To delete a secret from both Kubernetes and Azure Key Vault:

```bash
kubectl delete secret.keyvault.azure.upbound.io my-first-secret
```

**Warning**: This will delete the secret from Azure Key Vault as well!

## Common Patterns

### Pattern 1: Use Labels for Key Vault Selection

Instead of hardcoding the Key Vault ID, use labels (requires creating a Vault resource first):

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: labeled-secret
spec:
  forProvider:
    keyVaultIdSelector:
      matchLabels:
        keyvault: qubeio
    value: "Secret using label selector"
  providerConfigRef:
    name: default
```

### Pattern 2: Observe-Only Mode

To import existing secrets without managing them:

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: existing-secret
spec:
  forProvider:
    keyVaultId: /subscriptions/.../vaults/qubeio
  providerConfigRef:
    name: default
  managementPolicies:
    - "Observe"
```

### Pattern 3: Secret with Metadata

Add tags and content type:

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: tagged-secret
spec:
  forProvider:
    keyVaultId: /subscriptions/.../vaults/qubeio
    value: "Secret with metadata"
    contentType: "application/json"
    tags:
      environment: production
      application: my-app
      managed-by: crossplane
  providerConfigRef:
    name: default
```

## Getting Your Azure Subscription and Resource Group

If you don't know your subscription ID or resource group:

```bash
# Get subscription ID
az account show --query id -o tsv

# Find the resource group for your Key Vault
az keyvault show --name qubeio --query resourceGroup -o tsv
```

Then construct the full Key Vault ID:

```
/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.KeyVault/vaults/qubeio
```

## Troubleshooting

### Provider Not Healthy

```bash
# Check provider pods
kubectl get pods -n crossplane-system

# View provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault
```

### Credentials Not Found

```bash
# Check if credentials were synced
kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system

# Check sync job status
kubectl get jobs -n crossplane-system
kubectl logs -n crossplane-system job/sync-azure-credentials
```

### Secret Creation Failed

```bash
# Check secret status
kubectl describe secret.keyvault.azure.upbound.io <secret-name>

# Look for events and conditions
# Common issues:
# - Invalid Key Vault ID
# - Insufficient permissions
# - Authentication failure
```

## Next Steps

- Read the full [README.md](README.md) for detailed architecture
- Check the [example-secret.yaml](example-secret.yaml) for more examples
- Learn about [Crossplane Compositions](https://docs.crossplane.io/latest/concepts/compositions/) for advanced use cases

## Clean Up

To remove a secret:

```bash
kubectl delete secret.keyvault.azure.upbound.io <secret-name>
```

To disable Crossplane configuration (not recommended if in use):

```bash
kubectl delete application crossplane-config -n argocd
```

