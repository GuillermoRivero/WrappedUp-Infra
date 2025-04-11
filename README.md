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
kubectl create namespace wrappedup-infra
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

3. Create SonarQube database credentials:
```bash
# Generate a random password and create the secret
kubectl create secret generic sonarqube-db-credentials \
  -n wrappedup-infra \
  --from-literal=username=sonar \
  --from-literal=password=$(openssl rand -base64 32)
```

Note: Make sure to save the generated password securely, as it will be needed for SonarQube database access.

## Build and Deploy

The deployment process is split into two steps:

1. Build and push Docker images:
```bash
# Build for development (auto-incremental version)
./scripts/build.sh dev

# Build for development with specific version
./scripts/build.sh dev --version 1.0.0

# Build for production (auto-incremental version)
./scripts/build.sh prod

# Build for production with specific version
./scripts/build.sh prod --version 1.0.0

# Build specific components
./scripts/build.sh dev --frontend
./scripts/build.sh dev --backend
```

The build script includes:
- Automatic version incrementing for dev and prod environments
- SonarQube code quality analysis for the backend
- Environment-specific version tracking
- Docker image tagging with versions and latest tags

### Versioning System

The build system uses a versioning scheme that:
- Automatically increments versions for each environment
- Maintains separate version counters for dev and prod
- Appends `-dev` suffix to development versions
- Supports manual version specification

Version files:
- `.build-version-dev`: Tracks development versions
- `.build-version-prod`: Tracks production versions

### SonarQube Integration

The backend build process includes SonarQube analysis:
1. Set your SonarQube token:
```bash
export SONAR_TOKEN=your_sonar_token
```

2. The analysis will run automatically during backend builds
3. Results are available at https://wrappedup-sonarqube.duckdns.org
4. Each analysis is tagged with:
   - Version number
   - Environment (dev/prod)

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

# Terraform Configuration for WrappedUp Kubernetes Infrastructure

This directory contains Terraform configuration files to provision a Kubernetes cluster on Oracle Cloud Infrastructure (OCI) for the WrappedUp application.

## Structure

- `main.tf` - Main configuration file defining all infrastructure resources
- `variables.tf` - Variable definitions with sensible defaults
- `providers.tf` - Provider configuration
- `outputs.tf` - Output definitions that provide useful information after applying

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or higher)
2. [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) configured
3. [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (optional, for accessing the cluster)

## Authentication

The configuration uses the OCI provider which can be authenticated in several ways:

1. Environment variables:
   ```
   export OCI_TENANCY_OCID="ocid1.tenancy.oc1..xxx"
   export OCI_USER_OCID="ocid1.user.oc1..xxx"
   export OCI_FINGERPRINT="xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
   export OCI_PRIVATE_KEY_PATH="/path/to/oci_api_key.pem"
   export OCI_REGION="eu-madrid-1"
   ```

2. Using the OCI configuration file (`~/.oci/config`)

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the infrastructure plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. After successful application, get the kubeconfig:
   ```bash
   $(terraform output -raw kubeconfig_command)
   ```

## Customization

You can customize the infrastructure by modifying the variables in a `terraform.tfvars` file:

```hcl
region             = "eu-madrid-1"
compartment_id     = "ocid1.tenancy.oc1..xxx"
cluster_name       = "WrappedUp-Production"
kubernetes_version = "v1.32.1"
node_pool_size     = 3
node_ocpus         = 4
node_memory_in_gbs = 16
```

## Clean Up

To destroy the infrastructure:

```bash
terraform destroy
```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| `compartment_id` | OCI Compartment ID | *current value* |
| `region` | OCI Region | eu-madrid-1 |
| `cluster_name` | Name of the Kubernetes cluster | Wrappedup-Free-Cluster |
| `kubernetes_version` | Kubernetes version | v1.32.1 |
| `vcn_cidr` | CIDR block for the VCN | 10.0.0.0/16 |
| `node_subnet_cidr` | CIDR for the node subnet | 10.0.10.0/24 |
| `lb_subnet_cidr` | CIDR for the load balancer subnet | 10.0.20.0/24 |
| `api_endpoint_subnet_cidr` | CIDR for the Kubernetes API endpoint subnet | 10.0.0.0/28 |
| `node_pool_size` | Number of nodes in the node pool | 2 |
| `node_shape` | Shape of nodes | VM.Standard.A1.Flex |
| `node_ocpus` | Number of OCPUs for each node | 2 |
| `node_memory_in_gbs` | Amount of memory for each node in GB | 12 |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | The OCID of the created OKE cluster |
| `vcn_id` | The OCID of the VCN |
| `node_pool_id` | The OCID of the node pool |
| `lb_subnet_id` | The OCID of the load balancer subnet |
| `kubeconfig_command` | Command to generate kubeconfig file for the cluster | 

## Future Improvements

- [ ] Implement automated testing for Kubernetes configurations
- [ ] Add monitoring and alerting setup
- [ ] Implement backup and disaster recovery procedures 