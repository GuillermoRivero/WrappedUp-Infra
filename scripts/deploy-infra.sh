#!/bin/bash

# Default to dev if no environment specified
ENV=${1:-dev}

# Validate environment
if [ ! -d "k8s/overlays/${ENV}" ]; then
    echo "Error: Environment ${ENV} not found"
    exit 1
fi

# Set environment-specific variables
if [ "$ENV" = "dev" ]; then
    NAMESPACE="wrappedup-dev"
else
    NAMESPACE="wrappedup-prod"
fi

echo "Deploying infrastructure components to ${ENV} environment..."

# Create namespace if it doesn't exist
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Step 1: Apply MySQL secret if it doesn't exist
echo "Checking if MySQL secret exists..."
if ! kubectl get secret mysql-secret -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "Creating MySQL secret..."
    MYSQL_PASSWORD=$(openssl rand -base64 32)
    kubectl create secret generic mysql-secret \
        --from-literal=username=root \
        --from-literal=password="${MYSQL_PASSWORD}" \
        --namespace=${NAMESPACE}
    
    # Save the MySQL password to a secure file
    mkdir -p ~/.wrappedup
    echo "${MYSQL_PASSWORD}" > ~/.wrappedup/mysql-${ENV}-password.txt
    chmod 600 ~/.wrappedup/mysql-${ENV}-password.txt
    echo "MySQL password has been saved to ~/.wrappedup/mysql-${ENV}-password.txt"
fi

# Step 2: Apply infrastructure components using kustomize
echo "Applying infrastructure components..."

# Apply MySQL PV and PVC
kubectl apply -f k8s/overlays/${ENV}/mysql-pv.yaml
sleep 2  # Give the PV time to register

# Apply MySQL PVC only if it doesn't exist
if ! kubectl get pvc mysql-wrappedup-pvc -n ${NAMESPACE} >/dev/null 2>&1; then
    kubectl apply -f k8s/overlays/${ENV}/mysql-pvc.yaml
    
    # Wait for PVC to be bound
    echo "Waiting for PVC to be bound..."
    kubectl wait --for=condition=bound --timeout=60s pvc/mysql-wrappedup-pvc -n ${NAMESPACE} || true
fi

# Apply MySQL deployment and service
kubectl apply -f k8s/overlays/${ENV}/mysql-deployment.yaml

# Apply Ingress (if it exists in the environment overlay)
if [ -f "k8s/overlays/${ENV}/ingress.yaml" ]; then
    echo "Applying ingress configuration..."
    kubectl apply -f k8s/overlays/${ENV}/ingress.yaml
fi

# Wait for MySQL deployment to be ready
echo "Waiting for MySQL deployment to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment/mysql-wrappedup -n ${NAMESPACE} || true

# Print status information
echo "Infrastructure deployment complete for ${ENV} environment!"
echo "Namespace: ${NAMESPACE}"
echo "MySQL service: mysql-wrappedup-service.${NAMESPACE}.svc.cluster.local:3306"

# Show infrastructure component status in a simpler format
echo "=== Infrastructure Component Status ==="
echo "MySQL Resources in namespace: ${NAMESPACE}"
echo "----------------------------------------"

# Get PV directly by name
echo "Persistent Volume:"
kubectl get pv "mysql-pv-${ENV}"

# Get PVC in the namespace
echo -e "\nPersistent Volume Claim:"
kubectl get pvc -n "${NAMESPACE}"

# Get the MySQL deployment 
echo -e "\nMySQL Deployment:"
kubectl get deployment mysql-wrappedup -n "${NAMESPACE}"

# Get the MySQL service
echo -e "\nMySQL Service:"
kubectl get service mysql-wrappedup-service -n "${NAMESPACE}"

# Get ingress if it exists
if [ -f "k8s/overlays/${ENV}/ingress.yaml" ]; then
    echo -e "\nIngress Configuration:"
    kubectl get ingress -n "${NAMESPACE}"
fi

echo -e "\nCompleted infrastructure deployment for ${ENV} environment" 