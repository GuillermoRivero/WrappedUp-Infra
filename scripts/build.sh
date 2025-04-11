#!/bin/bash
set -e  # Exit on any error

# Function to show help
show_help() {
  echo "Usage: $0 [dev|prod] [--frontend] [--backend] [--all] [--version VERSION] [--help]"
  echo ""
  echo "Options:"
  echo "  dev|prod      Specify the environment (default: dev)"
  echo "  --frontend    Build only the frontend component"
  echo "  --backend     Build only the backend component"
  echo "  --all         Build all components (default if no component specified)"
  echo "  --version     Specify the version for this build (default: auto-incremental)"
  echo "  --help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 dev --frontend --version 1.0.0  # Build frontend v1.0.0 for dev environment"
  echo "  $0 prod --backend --version 1.0.0  # Build backend v1.0.0 for prod environment"
  echo "  $0 prod --version 1.0.0           # Build all components v1.0.0 for prod environment"
  exit 0
}

# Function to get the next build number
get_next_build_number() {
    local env=$1
    local version_file=".build-version-${env}"
    
    # Create version file if it doesn't exist
    if [ ! -f "$version_file" ]; then
        echo "1.0.0" > "$version_file"
    fi
    
    # Read current version
    local current_version=$(cat "$version_file")
    
    # Split version into major.minor.patch
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Increment patch version
    patch=$((patch + 1))
    
    # Create new version
    local new_version="${major}.${minor}.${patch}"
    
    # Save new version
    echo "$new_version" > "$version_file"
    
    echo "$new_version"
}

# Parse arguments
ENV="dev"  # Default environment
BUILD_FRONTEND=false
BUILD_BACKEND=false
VERSION=""  # Empty by default

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
    --version)
      VERSION="$2"
      shift
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

# If no version specified, generate incremental version
if [ -z "$VERSION" ]; then
    VERSION=$(get_next_build_number "$ENV")
    echo "Using auto-generated version: ${VERSION}"
fi

# Append -dev to dev versions
if [ "$ENV" = "dev" ]; then
    VERSION="${VERSION}-dev"
fi

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
    TAG="dev-${VERSION}"
else
    API_URL="https://wrappedupapi.duckdns.org"
    TAG="prod-${VERSION}"
fi

# Build frontend
if [ "$BUILD_FRONTEND" = "true" ]; then
    # Build frontend package
    echo "Compiling frontend package..."
    cd ../WrappedUp-frontend
    npm ci
    npm run build

    # Build and push frontend image
    echo "Building frontend image for ${ENV} environment (version: ${VERSION})..."
    docker build -t wrappedup-frontend-${ENV} --build-arg NEXT_PUBLIC_API_URL=$API_URL .

    echo "Tagging and pushing frontend image..."
    docker tag wrappedup-frontend-${ENV} ghcr.io/guillermorivero/wrappedup-frontend:${TAG}
    docker tag wrappedup-frontend-${ENV} ghcr.io/guillermorivero/wrappedup-frontend:${ENV}-latest
    docker push ghcr.io/guillermorivero/wrappedup-frontend:${TAG}
    docker push ghcr.io/guillermorivero/wrappedup-frontend:${ENV}-latest
    
    # Return to infrastructure directory
    cd ../WrappedUp-Infra
fi

# Build backend
if [ "$BUILD_BACKEND" = "true" ]; then
    # Build backend package with tests and SonarQube analysis
    echo "Compiling backend package..."
    cd ../WrappedUp-backend
    
    # Run tests and SonarQube analysis
    echo "Running tests and SonarQube analysis..."
    if [ -z "$SONAR_TOKEN" ]; then
        echo "Warning: SONAR_TOKEN not set. Skipping SonarQube analysis."
        ./mvnw clean verify
    else
        echo "Running SonarQube analysis for version ${VERSION}..."
        # Configure Git for SonarQube
        git config --global --add safe.directory "$(pwd)"
        ./mvnw clean verify sonar:sonar \
            -Dsonar.login=$SONAR_TOKEN \
            -Dsonar.projectVersion=${VERSION} \
            -Dsonar.projectName="WrappedUp Backend" \
            -Dsonar.projectKey="wrappedup-backend" \
            -Dsonar.tags="version:${VERSION},env:${ENV}" \
            -Dsonar.scm.provider=git \
            -Dsonar.git.provider=github
    fi

    # Build and push backend image
    echo "Building backend image for ${ENV} environment (version: ${VERSION})..."
    docker build -t wrappedup-backend-${ENV} .

    echo "Tagging and pushing backend image..."
    docker tag wrappedup-backend-${ENV} ghcr.io/guillermorivero/wrappedup-backend:${TAG}
    docker tag wrappedup-backend-${ENV} ghcr.io/guillermorivero/wrappedup-backend:${ENV}-latest
    docker push ghcr.io/guillermorivero/wrappedup-backend:${TAG}
    docker push ghcr.io/guillermorivero/wrappedup-backend:${ENV}-latest
    
    # Return to infrastructure directory
    cd ../WrappedUp-Infra
fi

echo "Build complete!"
echo "Version: ${VERSION}"
echo "Environment: ${ENV}"
echo "Images tagged with: ${TAG} and ${ENV}-latest"
echo "Components built: $([ "$BUILD_FRONTEND" = "true" ] && echo "Frontend ") $([ "$BUILD_BACKEND" = "true" ] && echo "Backend")" 