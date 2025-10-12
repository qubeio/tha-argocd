# Crossplane Azure Key Vault - Deployment Guide

This guide covers deploying Crossplane with Azure Key Vault integration via ArgoCD.

## Overview

This deployment configures Crossplane to manage secrets in Azure Key Vault (`qubeio`) using the same Azure credentials as External Secrets Operator.

## What Gets Deployed

### ArgoCD Applications

1. **crossplane** (existing)
   - Installs Crossplane core (Helm chart)
   - Namespace: `crossplane-system`
   - Sync Wave: 1

2. **crossplane-config** (new)
   - Installs Azure Key Vault provider
   - Syncs credentials from `external-secrets-system`
   - Creates ProviderConfig
   - Namespace: `crossplane-system`
   - Sync Wave: 3

### Resources Created

#### In `crossplane-system` namespace:

1. **Provider** (`provider-azure-keyvault`)
   - Package: `xpkg.upbound.io/upbound/provider-azure-keyvault:v1.4.0`
   - Manages Azure Key Vault resources

2. **ServiceAccount** (`crossplane-secret-sync`)
   - Used by the credential sync job
   - Has read access to `external-secrets-system` secrets
   - Has write access to `crossplane-system` secrets

3. **Job** (`sync-azure-credentials`)
   - Runs on each ArgoCD sync
   - Copies credentials from `external-secrets-system/azure-keyvault-credentials`
   - Creates `crossplane-system/azure-keyvault-crossplane-creds`
   - Auto-deletes after 5 minutes (ttlSecondsAfterFinished)

4. **Secret** (`azure-keyvault-crossplane-creds`)
   - JSON-formatted Azure credentials
   - Contains: clientId, clientSecret, tenantId, subscriptionId

5. **ProviderConfig** (`default`)
   - References the credentials secret
   - Used by all Azure Key Vault managed resources

## Prerequisites

### Required

- ✅ Crossplane installed (via `crossplane.yaml` Application)
- ✅ External Secrets Operator installed
- ✅ Secret `azure-keyvault-credentials` exists in `external-secrets-system` namespace with:
  - `clientId`: Azure service principal client ID
  - `clientSecret`: Azure service principal client secret  
  - `tenantId`: Azure AD tenant ID
  - `subscriptionId`: (Optional) Azure subscription ID

### Azure Permissions

The service principal must have these permissions on the `qubeio` Key Vault:

**Secret Permissions:**
- Get
- List
- Set
- Delete

**Key Permissions** (if managing keys):
- Get
- List
- Create
- Update

**Certificate Permissions** (if managing certificates):
- Get
- List

To set these permissions:

```bash
# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id <CLIENT_ID> --query id -o tsv)

# Set Key Vault access policies
az keyvault set-policy \
  --name qubeio \
  --object-id $SP_OBJECT_ID \
  --secret-permissions get list set delete \
  --key-permissions get list create update \
  --certificate-permissions get list
```

## Deployment Methods

### Method 1: Via ArgoCD (Recommended)

The `crossplane-config.yaml` Application manifest is in the `applications/fleet-manager/` directory, so it will be automatically picked up by the app-of-apps pattern.

**Steps:**

1. Commit and push all Crossplane configuration files to GitHub:

```bash
cd /home/andreas/source/repos/argo
git add applications/fleet-manager/crossplane/
git add applications/fleet-manager/crossplane-config.yaml
git commit -m "Add Crossplane Azure Key Vault configuration"
git push origin main
```

2. ArgoCD will automatically detect and deploy the new application:

```bash
# Watch the deployment
kubectl get applications -n argocd -w

# Check crossplane-config specifically
kubectl get application crossplane-config -n argocd
```

3. Verify the deployment:

```bash
cd applications/fleet-manager/crossplane
./verify-setup.sh
```

### Method 2: Manual Deployment (Testing)

For testing before committing to Git:

```bash
cd /home/andreas/source/repos/argo/applications/fleet-manager

# Deploy the configuration
kubectl apply -f crossplane-config.yaml

# Or apply resources directly
kubectl apply -k crossplane/
```

## Sync Waves Explained

The deployment uses ArgoCD sync waves to ensure proper ordering:

```
Wave 1: Crossplane Core
  └─ crossplane (Helm chart)
  
Wave 2: Providers
  └─ provider-azure-keyvault (Provider CRD)
  
Wave 3: Credentials & RBAC
  ├─ ServiceAccount
  ├─ Roles & RoleBindings
  └─ sync-azure-credentials Job
  
Wave 4: Configuration
  └─ ProviderConfig (default)
  
Wave 5: User Resources
  └─ Your Secret resources
```

This ensures:
1. Crossplane is running before providers are installed
2. Providers are healthy before credentials are synced
3. Credentials exist before ProviderConfig is created
4. Everything is ready before user resources are created

## Verification Steps

### 1. Check Provider Installation

```bash
kubectl get providers -n crossplane-system
```

Expected output:
```
NAME                         INSTALLED   HEALTHY   AGE
provider-azure-keyvault      True        True      5m
```

### 2. Check Credential Sync

```bash
# Check the sync job
kubectl get jobs -n crossplane-system

# View job logs
kubectl logs -n crossplane-system job/sync-azure-credentials

# Verify the secret was created
kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system
```

### 3. Check ProviderConfig

```bash
kubectl get providerconfigs
kubectl describe providerconfig default
```

### 4. Run Verification Script

```bash
cd applications/fleet-manager/crossplane
./verify-setup.sh
```

### 5. Test Secret Creation

Apply the example secret:

```bash
kubectl apply -f applications/fleet-manager/crossplane/example-secret.yaml
```

Check its status:

```bash
kubectl get secrets.keyvault.azure.upbound.io -n crossplane-system
kubectl describe secret.keyvault.azure.upbound.io example-keyvault-secret -n crossplane-system
```

Verify in Azure:

```bash
az keyvault secret show --vault-name qubeio --name example-secret
```

## Monitoring

### Watch All Crossplane Resources

```bash
kubectl get crossplane -n crossplane-system
```

### Watch Key Vault Secrets

```bash
kubectl get secrets.keyvault.azure.upbound.io -A -w
```

### View Provider Logs

```bash
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault --tail=50 -f
```

### ArgoCD UI

1. Open ArgoCD: http://argocd.test
2. Navigate to `crossplane-config` application
3. View the resource tree and sync status

## Troubleshooting

### Provider Not Healthy

**Symptom:** Provider shows `HEALTHY: False`

**Solution:**

```bash
# Check provider pods
kubectl get pods -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault

# View logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault

# Delete and recreate provider
kubectl delete provider provider-azure-keyvault
# ArgoCD will recreate it
```

### Credentials Not Synced

**Symptom:** Secret `azure-keyvault-crossplane-creds` doesn't exist

**Solution:**

```bash
# Check source secret
kubectl get secret azure-keyvault-credentials -n external-secrets-system

# Check job status
kubectl get jobs -n crossplane-system
kubectl logs -n crossplane-system job/sync-azure-credentials

# Manually re-run the job
kubectl delete job sync-azure-credentials -n crossplane-system
# ArgoCD will recreate it on next sync

# Or manually trigger ArgoCD sync
kubectl annotate application crossplane-config -n argocd \
  argocd.argoproj.io/refresh=now --overwrite
```

### ProviderConfig Not Found

**Symptom:** Resources fail with "cannot find ProviderConfig"

**Solution:**

```bash
# Check if ProviderConfig exists
kubectl get providerconfigs

# If missing, check sync waves
kubectl get application crossplane-config -n argocd -o yaml | grep sync-wave

# Force ArgoCD to re-sync
argocd app sync crossplane-config
```

### Authentication Failures

**Symptom:** Secrets fail to create with "authentication failed"

**Solution:**

```bash
# Verify credentials format
kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system \
  -o jsonpath='{.data.credentials}' | base64 -d | jq

# Test Azure authentication manually
az login --service-principal \
  --username <CLIENT_ID> \
  --password <CLIENT_SECRET> \
  --tenant <TENANT_ID>

az keyvault secret list --vault-name qubeio

# Check Key Vault permissions
az keyvault show --name qubeio --query properties.accessPolicies
```

### Permission Denied

**Symptom:** "caller does not have permission"

**Solution:**

```bash
# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id <CLIENT_ID> --query id -o tsv)

# Update Key Vault access policies
az keyvault set-policy \
  --name qubeio \
  --object-id $SP_OBJECT_ID \
  --secret-permissions get list set delete
```

## Updating Configuration

### Update Provider Version

Edit `crossplane/provider-azure.yaml`:

```yaml
spec:
  package: xpkg.upbound.io/upbound/provider-azure-keyvault:v1.5.0  # New version
```

Commit and push. ArgoCD will update the provider.

### Update Credentials

Credentials are synced from `external-secrets-system`. To update:

1. Update the source secret in `external-secrets-system`
2. Trigger a resync by deleting the sync job:

```bash
kubectl delete job sync-azure-credentials -n crossplane-system
```

3. ArgoCD will recreate the job and sync new credentials

### Add New ProviderConfigs

Create additional ProviderConfigs for different environments:

```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: production
spec:
  credentials:
    source: Secret
    secretRef:
      name: azure-production-creds
      namespace: crossplane-system
      key: credentials
```

## Cleanup

### Remove Crossplane Configuration Only

```bash
# Delete the ArgoCD application
kubectl delete application crossplane-config -n argocd

# This will remove:
# - Provider
# - ProviderConfig
# - Sync job and RBAC
# - Synced credentials secret
```

### Remove Everything Including Crossplane

```bash
# Delete both applications
kubectl delete application crossplane-config -n argocd
kubectl delete application crossplane -n argocd

# Clean up namespace
kubectl delete namespace crossplane-system
```

**Warning:** This will delete ALL Crossplane resources and managed resources in Azure!

## Security Considerations

1. **Credential Storage**: Credentials are stored as Kubernetes secrets. Consider:
   - Using Sealed Secrets for encrypted storage in Git
   - External Secrets Operator to fetch from a secure vault
   - Azure Workload Identity for credential-less authentication

2. **RBAC**: The sync job has minimal permissions:
   - Read-only to source secret
   - Write to single destination secret

3. **Secret Management**: 
   - Set `managementPolicies: ["Observe"]` for read-only import
   - Enable deletion protection on critical secrets
   - Use Azure Key Vault soft-delete and purge protection

4. **Audit Logging**:
   - Enable Azure Key Vault diagnostic logs
   - Monitor Crossplane events
   - Review ArgoCD sync history

## Next Steps

1. ✅ Deploy configuration via ArgoCD
2. ✅ Verify with `verify-setup.sh`
3. ✅ Test with example secret
4. 📖 Read [QUICKSTART.md](QUICKSTART.md) for usage examples
5. 📖 Read [README.md](README.md) for architecture details
6. 🚀 Create your first managed secret!

## Support

- Crossplane Docs: https://docs.crossplane.io/
- Upbound Provider: https://marketplace.upbound.io/providers/upbound/provider-azure-keyvault/
- ArgoCD Docs: https://argo-cd.readthedocs.io/

