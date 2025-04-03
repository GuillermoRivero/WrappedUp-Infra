variable "compartment_id" {
  description = "The OCID of the compartment where resources will be created"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaadov6zouscdscxo3e4yvzqv46jcpdd5ealjwy4xkzst5n3ruetd6a"
}

variable "region" {
  description = "The OCI region where resources will be created"
  type        = string
  default     = "eu-madrid-1"
}

variable "cluster_name" {
  description = "Name of the OKE cluster"
  type        = string
  default     = "Wrappedup-Free-Cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "v1.32.1"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_subnet_cidr" {
  description = "CIDR block for the node subnet"
  type        = string
  default     = "10.0.10.0/24"
}

variable "lb_subnet_cidr" {
  description = "CIDR block for the load balancer subnet"
  type        = string
  default     = "10.0.20.0/24"
}

variable "api_endpoint_subnet_cidr" {
  description = "CIDR block for the Kubernetes API endpoint subnet"
  type        = string
  default     = "10.0.0.0/28"
}

variable "node_pool_size" {
  description = "Number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "node_shape" {
  description = "Shape of the nodes"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_ocpus" {
  description = "Number of OCPUs for each node"
  type        = number
  default     = 2
}

variable "node_memory_in_gbs" {
  description = "Amount of memory for each node in GB"
  type        = number
  default     = 12
}

variable "availability_domain" {
  description = "Availability domain for the node pool"
  type        = string
  default     = "QTaI:EU-MADRID-1-AD-1"
}

variable "node_image_id" {
  description = "OCID of the node image"
  type        = string
  default     = "ocid1.image.oc1.eu-madrid-1.aaaaaaaaqwrcpirbdjbl2vq7m553x5bq63u5dijtbzkn3pekxz7p2iyx4s6a"
}

variable "service_cidr_block" {
  description = "Service CIDR block for OCI services"
  type        = string
  default     = "all-mad-services-in-oracle-services-network"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    "ManagedBy"   = "Terraform"
    "Project"     = "WrappedUp"
    "Environment" = "Production"
  }
} 