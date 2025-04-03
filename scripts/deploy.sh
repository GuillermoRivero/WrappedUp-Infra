#!/bin/bash

# Default to dev if no environment specified
ENV=${1:-dev}

# Validate environment
if [ ! -d "k8s/overlays/${ENV}" ]; then
    echo "Error: Environment ${ENV} not found"
    exit 1
fi

# Set tag based on environment
if [ "$ENV" = "dev" ]; then
    TAG="dev"
else
    TAG="prod"
fi

# Apply Kubernetes configurations
echo "Deploying to ${ENV} environment..."
kubectl apply -k k8s/overlays/${ENV}

# Restart deployments to ensure they pick up the new configurations
echo "Restarting deployments..."
kubectl rollout restart deployment/wrappedup-frontend -n wrappedup-${ENV}
kubectl rollout restart deployment/wrappedup-backend -n wrappedup-${ENV}

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/wrappedup-frontend -n wrappedup-${ENV}
kubectl wait --for=condition=available --timeout=300s deployment/wrappedup-backend -n wrappedup-${ENV}

echo "Deployment complete! Using image tag: ${TAG}" 