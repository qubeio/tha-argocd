# ArgoCD GitOps Repository

This repository contains the GitOps configuration for managing the Thanos multi-cluster orchestration platform using ArgoCD.

## Repository Structure

```
argocd/
├── applications/           # ArgoCD Application manifests
│   └── fleet-manager/      # Fleet manager cluster applications
├── clusters/               # Cluster configurations
├── projects/               # ArgoCD Project definitions
├── bootstrap/              # Bootstrap configurations
└── README.md              # This file
```

## Fleet Manager Cluster

The fleet-manager cluster is the control plane cluster that manages other clusters in the fleet.

### Applications

- **ArgoCD**: GitOps continuous delivery tool
- **Grafana**: Monitoring and observability dashboard
- **Prometheus**: Metrics collection and monitoring
- **Traefik**: Ingress controller and load balancer

### Cluster Configuration

The fleet-manager cluster is configured with:
- **API Server**: https://10.100.0.2:6443
- **Network**: 10.100.0.0/16 (homelab network)
- **Ingress**: Traefik with hostname-based routing

## Bootstrap Process

1. **Deploy ArgoCD**: Use the bootstrap configuration to install ArgoCD
2. **Configure Access**: Set up ingress and authentication
3. **Register Cluster**: Add the fleet-manager cluster to ArgoCD
4. **Deploy Applications**: Deploy the fleet-manager applications

## Usage

### Bootstrap the Fleet Manager Cluster

```bash
# Apply the bootstrap configuration
kubectl apply -f bootstrap/fleet-manager-bootstrap.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Access ArgoCD

Once deployed, ArgoCD will be available at:
- **URL**: https://argocd.test
- **Username**: admin
- **Password**: (from the secret above)

### Deploy Applications

```bash
# Deploy ArgoCD installation
kubectl apply -f applications/fleet-manager/argocd-install.yaml

# Deploy Grafana
kubectl apply -f applications/fleet-manager/grafana.yaml
```

## Network Configuration

The fleet-manager cluster is accessible via:
- **API Server**: https://10.100.0.2:6443
- **Ingress**: Traefik with hostname-based routing
- **DNS**: CoreDNS with `.test` domain resolution

## Security

- **RBAC**: Role-based access control for ArgoCD
- **TLS**: TLS termination at Traefik ingress
- **Network**: Secure communication via Tailscale mesh network

## Monitoring

- **Grafana**: https://grafana.test
- **Prometheus**: Metrics collection and alerting
- **ArgoCD**: Application status and health monitoring

## Troubleshooting

### Common Issues

1. **ArgoCD not accessible**: Check Traefik ingress configuration
2. **Application sync issues**: Check repository access and permissions
3. **Cluster connection issues**: Verify kubeconfig and network connectivity

### Logs

```bash
# ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# ArgoCD repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

## Contributing

1. Create a new branch for your changes
2. Make your changes to the appropriate files
3. Test the changes in a development environment
4. Submit a pull request

## License

This project is part of the Thanos multi-cluster orchestration platform.