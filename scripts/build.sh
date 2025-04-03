#!/bin/bash
set -e  # Exit on any error

# Function to show help
show_help() {
  echo "Usage: $0 [dev|prod] [--frontend] [--backend] [--all] [--help]"
  echo ""
  echo "Options:"
  echo "  dev|prod      Specify the environment (default: dev)"
  echo "  --frontend    Build only the frontend component"
  echo "  --backend     Build only the backend component"
  echo "  --all         Build all components (default if no component specified)"
  echo "  --help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 dev --frontend        # Build frontend for dev environment"
  echo "  $0 prod --backend        # Build backend for prod environment"
  echo "  $0 prod                  # Build all components for prod environment"
  exit 0
}

# Parse arguments
ENV="dev"  # Default environment
BUILD_FRONTEND=false
BUILD_BACKEND=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    dev|prod)
      ENV="$1"
      ;;
    --frontend)
      BUILD_FRONTEND=true
      ;;
    --backend)
      BUILD_BACKEND=true
      ;;
    --all)
      BUILD_FRONTEND=true
      BUILD_BACKEND=true
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

# If no components specified, build all by default
if [ "$BUILD_FRONTEND" = "false" ] && [ "$BUILD_BACKEND" = "false" ]; then
  BUILD_FRONTEND=true
  BUILD_BACKEND=true
fi

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

# Build frontend
if [ "$BUILD_FRONTEND" = "true" ]; then
    # Build frontend package
    echo "Compiling frontend package..."
    cd ../WrappedUp-frontend
    npm ci
    npm run build

    # Build and push frontend image
    echo "Building frontend image for ${ENV} environment..."
    docker build -t wrappedup-frontend-${ENV} --build-arg NEXT_PUBLIC_API_URL=$API_URL .

    echo "Tagging and pushing frontend image..."
    docker tag wrappedup-frontend-${ENV} ghcr.io/guillermorivero/wrappedup-frontend:${TAG}
    docker push ghcr.io/guillermorivero/wrappedup-frontend:${TAG}
    
    # Return to infrastructure directory
    cd ../WrappedUp-Infra
fi

# Build backend
if [ "$BUILD_BACKEND" = "true" ]; then
    # Build backend package
    echo "Compiling backend package..."
    cd ../WrappedUp-backend
    ./mvnw clean package -DskipTests

    # Build and push backend image
    echo "Building backend image for ${ENV} environment..."
    docker build -t wrappedup-backend-${ENV} .

    echo "Tagging and pushing backend image..."
    docker tag wrappedup-backend-${ENV} ghcr.io/guillermorivero/wrappedup-backend:${TAG}
    docker push ghcr.io/guillermorivero/wrappedup-backend:${TAG}
    
    # Return to infrastructure directory
    cd ../WrappedUp-Infra
fi

echo "Build complete! Images tagged with: ${TAG}"
echo "Components built: $([ "$BUILD_FRONTEND" = "true" ] && echo "Frontend ") $([ "$BUILD_BACKEND" = "true" ] && echo "Backend")" 