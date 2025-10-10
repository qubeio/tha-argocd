# CLI API Manifests

This directory contains Kubernetes manifests for exposing the CLI API through Traefik ingress.

## Files

- `external-service.yaml` - ExternalName service that points to the CLI API container
- `ingress.yaml` - Kubernetes Ingress for routing traffic to the CLI API through Traefik

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │   Traefik        │    │   Docker        │
│   Cluster       │◄──►│   LoadBalancer   │◄──►│   Container     │
│   (ArgoCD)      │    │   (10.100.200.51)│    │   (cli-api.test)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Access

Once deployed, the CLI API will be accessible at:

- **API**: http://cli-api.test
- **Docs**: http://cli-api.test/docs
- **Health**: http://cli-api.test/health

## Dependencies

- Traefik must be deployed and running (sync-wave: 3)
- CLI API container must be running on the host
- DNS resolution must be working for cli-api.test

## Deployment

This is managed by ArgoCD as part of the fleet-manager applications with sync-wave: 4, ensuring it deploys after Traefik.
