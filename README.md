# WrappedUp Infrastructure

This repository contains the infrastructure configuration for the WrappedUp application, including Kubernetes manifests and deployment scripts.

## Prerequisites

- Kubernetes cluster
- `kubectl` configured to access your cluster
- Docker installed and configured
- Access to GitHub Container Registry (ghcr.io)
- GitHub Container Registry secret configured in your cluster

## Project Structure

```
WrappedUp-Infra/
├── k8s/
│   ├── base/           # Base Kubernetes configurations
│   │   ├── frontend-deployment.yaml
│   │   ├── backend-deployment.yaml
│   │   ├── configmap.yaml
│   │   └── kustomization.yaml
│   └── overlays/       # Environment-specific overlays
│       ├── dev/        # Development environment
│       └── prod/       # Production environment
├── scripts/
│   ├── build.sh       # Script to build and push Docker images
│   └── deploy.sh      # Script to deploy to Kubernetes
└── README.md
```

## Initial Setup

1. Create the required namespaces:
```bash
kubectl create namespace wrappedup-dev
kubectl create namespace wrappedup-prod
```

2. Configure GitHub Container Registry secret in each namespace:
```bash
kubectl create secret docker-registry github-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-username> \
  --docker-password=<your-token> \
  --namespace=wrappedup-dev

kubectl create secret docker-registry github-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-username> \
  --docker-password=<your-token> \
  --namespace=wrappedup-prod
```

## Build and Deploy

The deployment process is split into two steps:

1. Build and push Docker images:
```bash
# Build for development
./scripts/build.sh dev

# Build for production
./scripts/build.sh prod
```

2. Deploy to Kubernetes:
```bash
# Deploy to development
./scripts/deploy.sh dev

# Deploy to production
./scripts/deploy.sh prod
```

The deploy script will:
1. Apply all Kubernetes configurations using Kustomize
2. Restart the deployments to ensure they pick up new configurations
3. Wait for all deployments to be ready before completing

## Environment Configuration

### Development
- API URL: https://wrappedupapidev.duckdns.org
- Namespace: wrappedup-dev
- Image tag: dev

### Production
- API URL: https://wrappedupapi.duckdns.org
- Namespace: wrappedup-prod
- Image tag: prod

## Monitoring Deployments

Check deployment status:
```bash
# For development
kubectl get deployments -n wrappedup-dev

# For production
kubectl get deployments -n wrappedup-prod
```

View logs:
```bash
# For development
kubectl logs -f deployment/wrappedup-frontend -n wrappedup-dev
kubectl logs -f deployment/wrappedup-backend -n wrappedup-dev

# For production
kubectl logs -f deployment/wrappedup-frontend -n wrappedup-prod
kubectl logs -f deployment/wrappedup-backend -n wrappedup-prod
```

## Troubleshooting

1. Check namespace status:
```bash
kubectl get namespace wrappedup-${ENV}
```

2. Verify ConfigMaps:
```bash
kubectl get configmap -n wrappedup-${ENV}
```

3. Check pod status:
```bash
kubectl get pods -n wrappedup-${ENV}
```

4. View pod logs:
```bash
kubectl logs -f <pod-name> -n wrappedup-${ENV}
```

## Adding New Resources

1. Add base configuration in `k8s/base/`
2. Create environment-specific patches in `k8s/overlays/${ENV}/`
3. Update the `kustomization.yaml` files to include new resources
4. Deploy using the scripts

## Future Improvements

- [ ] Add Terraform configurations for infrastructure provisioning
- [ ] Implement automated testing for Kubernetes configurations
- [ ] Add monitoring and alerting setup
- [ ] Implement backup and disaster recovery procedures 