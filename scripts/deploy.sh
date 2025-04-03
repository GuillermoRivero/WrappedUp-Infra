#!/bin/bash
set -e  # Exit on any error

# Function to show help
show_help() {
  echo "Usage: $0 [dev|prod] [--frontend] [--backend] [--all] [--no-infra] [--help]"
  echo ""
  echo "Options:"
  echo "  dev|prod      Specify the environment (default: dev)"
  echo "  --frontend    Deploy only the frontend component"
  echo "  --backend     Deploy only the backend component"
  echo "  --all         Deploy all components (default if no component specified)"
  echo "  --no-infra    Skip infrastructure deployment (ConfigMaps, Services, etc.)"
  echo "  --help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 dev --frontend        # Deploy frontend for dev environment"
  echo "  $0 prod --backend        # Deploy backend for prod environment"
  echo "  $0 prod --all --no-infra # Deploy all components but skip infrastructure changes"
  exit 0
}

# Parse arguments
ENV="dev"  # Default environment
DEPLOY_FRONTEND=false
DEPLOY_BACKEND=false
DEPLOY_INFRA=true  # Always deploy infrastructure by default

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    dev|prod)
      ENV="$1"
      ;;
    --frontend)
      DEPLOY_FRONTEND=true
      ;;
    --backend)
      DEPLOY_BACKEND=true
      ;;
    --all)
      DEPLOY_FRONTEND=true
      DEPLOY_BACKEND=true
      ;;
    --no-infra)
      DEPLOY_INFRA=false
      ;;
    --help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
  shift
done

# If no components specified, deploy all by default
if [ "$DEPLOY_FRONTEND" = "false" ] && [ "$DEPLOY_BACKEND" = "false" ]; then
  DEPLOY_FRONTEND=true
  DEPLOY_BACKEND=true
fi

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

# Apply Kubernetes configurations if requested
if [ "$DEPLOY_INFRA" = "true" ]; then
    echo "Deploying infrastructure to ${ENV} environment..."
    kubectl apply -k k8s/overlays/${ENV}
else
    echo "Skipping infrastructure deployment as requested with --no-infra"
fi

# List of components to be deployed
COMPONENTS=""

# Restart frontend deployment if requested
if [ "$DEPLOY_FRONTEND" = "true" ]; then
    echo "Restarting frontend deployment..."
    kubectl rollout restart deployment/wrappedup-frontend -n wrappedup-${ENV}
    COMPONENTS="$COMPONENTS Frontend"
fi

# Restart backend deployment if requested
if [ "$DEPLOY_BACKEND" = "true" ]; then
    echo "Restarting backend deployment..."
    kubectl rollout restart deployment/wrappedup-backend -n wrappedup-${ENV}
    COMPONENTS="$COMPONENTS Backend"
fi

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."

if [ "$DEPLOY_FRONTEND" = "true" ]; then
    kubectl wait --for=condition=available --timeout=300s deployment/wrappedup-frontend -n wrappedup-${ENV}
fi

if [ "$DEPLOY_BACKEND" = "true" ]; then
    kubectl wait --for=condition=available --timeout=300s deployment/wrappedup-backend -n wrappedup-${ENV}
fi

echo "Deployment complete! Using image tag: ${TAG}"
echo "Components deployed:$COMPONENTS" 