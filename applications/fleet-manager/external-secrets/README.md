# External Secrets Operator Configuration

This directory contains the configuration for the External Secrets Operator (ESO) in the Fleet Manager cluster.

## Overview

The External Secrets Operator integrates external secret management systems with Kubernetes. It automatically synchronizes secrets from external systems into Kubernetes secrets.

## Files

- `cluster-secret-store.yaml` - ClusterSecretStore configuration for Akeyless
- `example-external-secret.yaml` - Example ExternalSecret resources showing common patterns

## Setup

### 1. Configure Akeyless Credentials

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
      akeylessGWApiURL: "https://your-gateway.akeyless.io"  # Change to your gateway URL
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
```

## Security Considerations

1. **Akeyless Access Control**: Ensure the Akeyless credentials have minimal required permissions
2. **RBAC**: The External Secrets Operator runs with appropriate RBAC permissions
3. **Network**: Secrets are fetched over HTTPS from Akeyless
4. **Encryption**: Secrets are encrypted at rest in Kubernetes using etcd encryption

## Troubleshooting

### Common Issues

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
```
