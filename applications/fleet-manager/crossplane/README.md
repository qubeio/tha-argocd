# Crossplane Azure Key Vault Configuration

This directory contains Crossplane configuration for managing Azure Key Vault secrets.

## Overview

Crossplane is configured to use the Azure Provider to manage secrets in the `qubeio` Azure Key Vault. The configuration reuses the same Azure credentials that External Secrets Operator uses.

## Components

### 1. Provider Installation

#### Azure Provider (`provider-azure.yaml`)

Installs the Upbound Azure Key Vault provider for Crossplane. This provider enables Crossplane to manage Azure Key Vault resources.

- **Provider**: `xpkg.upbound.io/upbound/provider-azure-keyvault:v1.4.0`
- **Sync Wave**: 2 (installs after Crossplane core)

#### Kubernetes Provider (`provider-kubernetes.yaml`)

Installs the CrossPlane Kubernetes provider for managing Kubernetes resources. This provider enables CrossPlane to create and manage Kubernetes objects like ConfigMaps, Secrets, Deployments, etc.

- **Provider**: `xpkg.upbound.io/upbound/provider-kubernetes:v1.0.0`
- **Sync Wave**: 2 (installs after Crossplane core)

### 2. Credential Setup (`setup-credentials.sh`)

A one-time manual script that copies Azure credentials from `external-secrets-system` namespace to `crossplane-system` namespace. This allows both External Secrets Operator and Crossplane to use the same credentials.

**What it does:**
- Reads `azure-keyvault-credentials` secret from `external-secrets-system` namespace
- Extracts: `clientId`, `clientSecret`, `tenantId`, and `subscriptionId` (if available)
- Creates `azure-keyvault-crossplane-creds` secret in `crossplane-system` namespace
- Formats credentials as JSON for Crossplane provider

**Usage:**
```bash
cd applications/fleet-manager/crossplane
./setup-credentials.sh
```

**Note**: Run this once before deploying the Crossplane configuration. In production, credentials would be managed outside of GitOps.

### 3. Provider Configuration

#### Azure Provider Config (`provider-config.yaml`)

Configures the Azure provider with authentication credentials.

- **ProviderConfig Name**: `default` (used by all Azure resources unless specified)
- **Credentials Source**: Secret reference to `azure-keyvault-crossplane-creds` (created manually)
- **Sync Wave**: 3 (after provider installation)

#### Kubernetes Provider Config (`provider-config-kubernetes.yaml`)

Configures the Kubernetes provider with authentication using the cluster's service account.

- **ProviderConfig Name**: `default` (used by all Kubernetes resources unless specified)
- **Credentials Source**: `InjectedIdentity` (uses CrossPlane's service account permissions)
- **Sync Wave**: 3 (after provider installation)

### 4. Example Resources (`example-secret.yaml`)

Example manifests showing how to:
- Write secrets to Azure Key Vault
- Reference existing Key Vault resources
- Use management policies for import/observe-only mode

**Note**: This file is commented out in `kustomization.yaml` by default.

## Architecture

```
┌─────────────────────────────────────┐
│  external-secrets-system namespace  │
│  ┌───────────────────────────────┐  │
│  │ azure-keyvault-credentials    │  │
│  │ - clientId                    │  │
│  │ - clientSecret                │  │
│  │ - tenantId                    │  │
│  │ - subscriptionId (optional)   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
                 │
                 │ (Manual setup script copies once)
                 ▼
┌─────────────────────────────────────┐
│    crossplane-system namespace      │
│  ┌───────────────────────────────┐  │
│  │azure-keyvault-crossplane-creds│  │
│  │ JSON formatted credentials    │  │
│  └───────────────────────────────┘  │
│                │                     │
│                ▼                     │
│  ┌───────────────────────────────┐  │
│  │ ProviderConfig (default)      │  │
│  │ - Uses credentials from above │  │
│  └───────────────────────────────┘  │
│                │                     │
│                ▼                     │
│  ┌───────────────────────────────┐  │
│  │ Azure Provider                │  │
│  │ - Manages Key Vault resources │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
                 │
                 ▼
        Azure Key Vault (qubeio)
        https://qubeio.vault.azure.net/
```

## Usage

### Writing a Secret to Azure Key Vault

Create a `Secret` resource in your namespace:

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: my-application-secret
  namespace: my-namespace
spec:
  forProvider:
    keyVaultId: /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.KeyVault/vaults/qubeio
    value: "my-secret-value"
    contentType: "text/plain"
  providerConfigRef:
    name: default
```

### Using a Selector (Recommended)

Instead of hardcoding the Key Vault ID, use labels:

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: my-application-secret
spec:
  forProvider:
    keyVaultIdSelector:
      matchLabels:
        keyvault: qubeio
    value: "my-secret-value"
  providerConfigRef:
    name: default
```

### Reading from Kubernetes Secrets

You can reference Kubernetes secrets as the source:

```yaml
apiVersion: keyvault.azure.upbound.io/v1beta1
kind: Secret
metadata:
  name: sync-to-keyvault
spec:
  forProvider:
    keyVaultIdSelector:
      matchLabels:
        keyvault: qubeio
    valueSecretRef:
      name: source-secret
      namespace: my-namespace
      key: password
  providerConfigRef:
    name: default
```

### Using the Kubernetes Provider

The Kubernetes provider allows CrossPlane to manage Kubernetes resources. Here are some examples:

#### Creating a ConfigMap

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: my-configmap
  namespace: my-namespace
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: my-configmap
        namespace: my-namespace
      data:
        key1: value1
        key2: value2
  providerConfigRef:
    name: default
```

#### Creating a Deployment

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: my-deployment
  namespace: my-namespace
spec:
  forProvider:
    manifest:
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: my-deployment
        namespace: my-namespace
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: my-app
        template:
          metadata:
            labels:
              app: my-app
          spec:
            containers:
            - name: my-app
              image: nginx:latest
              ports:
              - containerPort: 80
  providerConfigRef:
    name: default
```

## Prerequisites

1. **Azure Credentials**: The `azure-keyvault-credentials` secret must exist in the `external-secrets-system` namespace with the following keys:
   - `clientId`: Azure AD application (service principal) client ID
   - `clientSecret`: Azure AD application client secret
   - `tenantId`: Azure AD tenant ID
   - `subscriptionId`: (Optional) Azure subscription ID

2. **Azure Permissions**: The service principal must have appropriate permissions on the Key Vault:
   - Key Permissions: Get, List, Create, Update (if managing keys)
   - Secret Permissions: Get, List, Set, Delete (for secret management)
   - Certificate Permissions: Get, List (if managing certificates)

3. **Crossplane Installation**: Crossplane must be installed (sync-wave 1)

4. **External Secrets Operator**: Must be installed with credentials already configured (sync-wave 2)

5. **Manual Credential Setup**: Run `./setup-credentials.sh` once to create the credentials secret in crossplane-system

## Sync Waves

The deployment follows this order:
1. **Wave 1**: Crossplane core installation
2. **Wave 2**: Azure provider installation
3. **Wave 3**: ProviderConfig creation (requires manual credential setup first)
4. **Wave 4+**: User resources (your Secret resources)

## Verification

### Check Provider Installation

```bash
kubectl get providers -n crossplane-system
```

Expected output:
```
NAME                         INSTALLED   HEALTHY   AGE
provider-azure-keyvault      True        True      5m
```

### Check Provider Config

```bash
kubectl get providerconfigs
```

Expected output:
```
NAME      AGE
default   5m
```

### Check Credentials

```bash
# View the synced credentials (without exposing values)
kubectl get secret azure-keyvault-crossplane-creds \
  -n crossplane-system \
  -o jsonpath='{.data.credentials}' | base64 -d | jq
```

### Test Secret Creation

Apply the example secret:

```bash
kubectl apply -f example-secret.yaml
```

Check the status:

```bash
kubectl get secrets.keyvault.azure.upbound.io -n crossplane-system
kubectl describe secret.keyvault.azure.upbound.io example-keyvault-secret -n crossplane-system
```

Verify in Azure:

```bash
az keyvault secret show --vault-name qubeio --name example-secret
```

## Troubleshooting

### Provider Not Ready

Check provider logs:

```bash
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault
```

### Credentials Not Found

If the credentials secret doesn't exist:

```bash
# Run the setup script
cd applications/fleet-manager/crossplane
./setup-credentials.sh
```

To update credentials:

```bash
# Delete the old secret
kubectl delete secret azure-keyvault-crossplane-creds -n crossplane-system

# Re-run the setup script
./setup-credentials.sh
```

### Secret Not Created in Key Vault

Check the secret resource status:

```bash
kubectl describe secret.keyvault.azure.upbound.io <secret-name>
```

Check provider logs for errors:

```bash
kubectl logs -n crossplane-system \
  -l pkg.crossplane.io/provider=provider-azure-keyvault \
  --tail=100
```

Common issues:
- **Authentication failed**: Check service principal credentials
- **Permission denied**: Verify Key Vault access policies
- **Key Vault not found**: Ensure the Key Vault ID or selector is correct

## Security Considerations

1. **Credential Storage**: Credentials are stored as Kubernetes secrets. In production, consider using External Secrets Operator, Sealed Secrets, or Azure Workload Identity.

2. **Manual Setup**: This lab setup uses manual credential creation. Production environments should automate this outside of GitOps.

3. **Secret Cleanup**: When secrets are deleted from Kubernetes, Crossplane will also delete them from Azure Key Vault (unless using `managementPolicies: ["Observe"]`).

4. **Audit**: All Key Vault operations are logged in Azure Monitor. Enable diagnostic settings on the Key Vault for audit trail.

## References

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Upbound Azure Provider](https://marketplace.upbound.io/providers/upbound/provider-azure-keyvault/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)

