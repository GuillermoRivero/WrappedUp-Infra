provider "oci" {
  region = var.region
  # Authentication can be configured through environment variables:
  # OCI_TENANCY_OCID, OCI_USER_OCID, OCI_FINGERPRINT, OCI_PRIVATE_KEY_PATH, OCI_REGION
  # Or through ~/.oci/config file
}

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.0.0"
} 