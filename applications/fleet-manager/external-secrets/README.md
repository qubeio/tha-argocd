# External Secrets Operator Configuration

This directory contains the configuration for the External Secrets Operator (ESO) in the Fleet Manager cluster.

## Overview

The External Secrets Operator integrates external secret management systems with Kubernetes. It automatically synchronizes secrets from external systems into Kubernetes secrets.

## Files

- `cluster-secret-store.yaml` - ClusterSecretStore configuration for Akeyless
- `example-external-secret.yaml` - Example ExternalSecret resources showing common patterns
- `azure-key-vault-store.yaml` - ClusterSecretStore configuration for Azure Key Vault
- `azure-key-vault-example.yaml` - Example ExternalSecret resources for Azure Key Vault
- `create-azure-credentials.sh` - Script to create Azure credentials secret manually

## Setup

### Azure Key Vault Configuration

#### 1. Create Azure Credentials Secret

**⚠️ SECURITY WARNING**: Never check Azure credential values into Git. Manually create the required Kubernetes secret using the values for your environment:

```bash
kubectl create secret generic azure-keyvault-credentials \
  --namespace external-secrets-system \
  --from-literal=clientId="<YOUR_AZURE_SERVICE_PRINCIPAL_CLIENT_ID>" \
  --from-literal=clientSecret="<YOUR_AZURE_SERVICE_PRINCIPAL_CLIENT_SECRET>" \
  --from-literal=tenantId="<YOUR_AZURE_TENANT_ID>"
```

This will create a secret named `azure-keyvault-credentials` in the `external-secrets-system` namespace with the following keys:
- `clientId`: Your Azure Service Principal Client ID
- `clientSecret`: Your Azure Service Principal Client Secret
- `tenantId`: Your Azure Tenant ID

#### 2. Configure Azure Key Vault URL

Update the `vaultUrl` in `azure-key-vault-store.yaml` to match your actual Azure Key Vault URL:

```yaml
spec:
  provider:
    azurekv:
      vaultUrl: "https://your-keyvault-name.vault.azure.net/"  # Replace with your Key Vault URL
```

#### 3. Azure Key Vault Access Policies

Ensure your Azure Key Vault has the necessary access policies for the service principal:

1. **Get Secret**: The service principal needs "Get" permission for secrets
2. **List Secret**: The service principal needs "List" permission for secrets

You can configure this via Azure CLI:

```bash
# Set the Key Vault access policy for the service principal
az keyvault set-policy \
  --name your-keyvault-name \
  --spn YOUR_SERVICE_PRINCIPAL_CLIENT_ID \
  --secret-permissions get list
```

#### 4. Create Secrets in Azure Key Vault

Create secrets in your Azure Key Vault that you want to sync to Kubernetes:

```bash
# Example: Create a simple secret
az keyvault secret set \
  --vault-name your-keyvault-name \
  --name "github-token" \
  --value "your-github-token"

# Example: Create a JSON secret
az keyvault secret set \
  --vault-name your-keyvault-name \
  --name "database-credentials" \
  --value '{"username":"dbuser","password":"dbpass","host":"dbhost","port":"5432"}'
```

### Akeyless Configuration

#### 1. Configure Akeyless Credentials

Before deploying, you need to configure Akeyless credentials in the `cluster-secret-store.yaml` file:

```bash
# Encode your Akeyless credentials
echo -n "YOUR_ACCESS_ID" | base64
echo -n "YOUR_ACCESS_KEY" | base64
```

Update the `akeyless-credentials` secret in `cluster-secret-store.yaml` with the base64-encoded values.

### 2. Configure Akeyless Gateway URL

Update the gateway URL in `cluster-secret-store.yaml` to match your Akeyless setup:

```yaml
spec:
  provider:
    akeyless:
      akeylessGWApiURL: "https://api.akeyless.io"  # Change to your gateway URL
      authSecretRef:
        accessIdSecretRef:
          name: akeyless-credentials
          key: access-id
          namespace: external-secrets-system
        accessKeySecretRef:
          name: akeyless-credentials
          key: access-key
          namespace: external-secrets-system
```

### 3. Create Secrets in Akeyless

Create the following secrets in Akeyless:

#### Database Credentials
- **Secret Name**: `/fleet-manager/database/credentials`
- **Format**: JSON
```json
{
  "username": "your-db-user",
  "password": "your-db-password",
  "host": "your-db-host",
  "port": "5432",
  "database": "your-db-name"
}
```

#### API Keys
- **Secret Name**: `/fleet-manager/api-keys/github`
- **Format**: JSON
```json
{
  "token": "your-github-token"
}
```

- **Secret Name**: `/fleet-manager/api-keys/dockerhub`
- **Format**: JSON
```json
{
  "token": "your-dockerhub-token"
}
```

- **Secret Name**: `/fleet-manager/api-keys/slack`
- **Format**: JSON
```json
{
  "webhook-url": "your-slack-webhook-url"
}
```

## Usage

### Azure Key Vault External Secrets

#### Creating New Azure Key Vault External Secrets

1. Create a new ExternalSecret resource in your application namespace
2. Reference the ClusterSecretStore: `azure-key-vault-secrets`
3. Define the secret mapping from Azure Key Vault to Kubernetes secrets

Example for simple secrets:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-azure-secrets
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-key-vault-secrets
    kind: ClusterSecretStore
  target:
    name: my-app-credentials
    creationPolicy: Owner
  data:
    - secretKey: github-token
      remoteRef:
        key: github-token
    - secretKey: api-key
      remoteRef:
        key: my-app-api-key
```

Example for JSON secrets with property extraction:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secrets
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-key-vault-secrets
    kind: ClusterSecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: database-credentials
        property: username
    - secretKey: password
      remoteRef:
        key: database-credentials
        property: password
    - secretKey: host
      remoteRef:
        key: database-credentials
        property: host
```

### Creating New External Secrets

1. Create a new ExternalSecret resource in your application namespace
2. Reference the ClusterSecretStore: `akeyless-secrets`
3. Define the secret mapping from Akeyless to Kubernetes secrets

Example:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: akeyless-secrets
    kind: ClusterSecretStore
  target:
    name: my-app-credentials
    creationPolicy: Owner
  data:
    - secretKey: api-key
      remoteRef:
        key: /my-app/api-keys
        property: key
```

### Monitoring

Check the status of External Secrets:

```bash
# List all External Secrets
kubectl get externalsecrets -A

# Check status of a specific External Secret
kubectl describe externalsecret my-app-secrets -n my-app

# Check ClusterSecretStore status
kubectl describe clustersecretstore akeyless-secrets
kubectl describe clustersecretstore azure-key-vault-secrets

# Check Azure credentials secret
kubectl get secret azure-keyvault-credentials -n external-secrets-system
```

## Security Considerations

1. **Azure Key Vault Access Control**: Ensure the service principal has minimal required permissions (Get, List secrets only)
2. **Akeyless Access Control**: Ensure the Akeyless credentials have minimal required permissions
3. **RBAC**: The External Secrets Operator runs with appropriate RBAC permissions
4. **Network**: Secrets are fetched over HTTPS from Azure Key Vault and Akeyless
5. **Encryption**: Secrets are encrypted at rest in Kubernetes using etcd encryption
6. **Credential Storage**: Azure credentials are stored in Kubernetes secrets, not in Git

## Troubleshooting

### Common Issues

#### Azure Key Vault Issues

1. **Authentication Errors**: 
   - Verify Azure service principal credentials in the `azure-keyvault-credentials` secret
   - Check that the service principal has proper access policies in Azure Key Vault
   - Ensure the tenant ID matches your Azure subscription

2. **Secret Not Found**: 
   - Check the secret name in Azure Key Vault matches the `key` in your ExternalSecret
   - Verify the Key Vault URL is correct in the ClusterSecretStore
   - Ensure the secret exists and is accessible by the service principal

3. **Access Denied**: 
   - Verify the service principal has "Get" and "List" permissions for secrets
   - Check that the Key Vault access policy is properly configured

#### Akeyless Issues

1. **Authentication Errors**: Verify Akeyless credentials and access permissions
2. **Secret Not Found**: Check the secret name and path in Akeyless
3. **Sync Issues**: Check the ExternalSecret status and logs

### Debug Commands

```bash
# Check ESO logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Check webhook logs
kubectl logs -n external-secrets-system deployment/external-secrets-webhook

# Check cert controller logs
kubectl logs -n external-secrets-system deployment/external-secrets-cert-controller

# Check Azure Key Vault ClusterSecretStore status
kubectl describe clustersecretstore azure-key-vault-secrets

# Check Azure credentials secret
kubectl get secret azure-keyvault-credentials -n external-secrets-system -o yaml

# Test Azure Key Vault connectivity (if Azure CLI is available)
az keyvault secret list --vault-name your-keyvault-name --query "[].name" -o table
```
