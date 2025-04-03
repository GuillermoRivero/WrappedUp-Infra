#!/bin/bash

# Default to dev if no environment specified
ENV=${1:-dev}

# Validate environment
if [ ! -d "k8s/overlays/${ENV}" ]; then
    echo "Error: Environment ${ENV} not found"
    exit 1
fi

# Set API URL and tag based on environment
if [ "$ENV" = "dev" ]; then
    API_URL="https://wrappedupapidev.duckdns.org"
    TAG="dev"
else
    API_URL="https://wrappedupapi.duckdns.org"
    TAG="prod"
fi

# Build and push frontend image
echo "Building frontend image for ${ENV} environment..."
cd ../WrappedUp-frontend
docker build -t wrappedup-frontend-${ENV} --build-arg NEXT_PUBLIC_API_URL=$API_URL .

echo "Tagging and pushing frontend image..."
docker tag wrappedup-frontend-${ENV} ghcr.io/guillermorivero/wrappedup-frontend:${TAG}
docker push ghcr.io/guillermorivero/wrappedup-frontend:${TAG}

# Build and push backend image
echo "Building backend image for ${ENV} environment..."
cd ../WrappedUp-backend
docker build -t wrappedup-backend-${ENV} .

echo "Tagging and pushing backend image..."
docker tag wrappedup-backend-${ENV} ghcr.io/guillermorivero/wrappedup-backend:${TAG}
docker push ghcr.io/guillermorivero/wrappedup-backend:${TAG}

# Return to infrastructure directory
cd ../WrappedUp-Infra

echo "Build complete! Images tagged with: ${TAG}" 