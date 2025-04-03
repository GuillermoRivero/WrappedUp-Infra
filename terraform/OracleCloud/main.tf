locals {
	common_tags = merge(var.tags, {
		"OKEclusterName" = var.cluster_name
	})
}

resource "oci_core_vcn" "oke_vcn" {
	cidr_block = var.vcn_cidr
	compartment_id = var.compartment_id
	display_name = "oke-vcn-${var.cluster_name}"
	dns_label = replace(var.cluster_name, "-", "")
	freeform_tags = local.common_tags
}

resource "oci_core_internet_gateway" "oke_igw" {
	compartment_id = var.compartment_id
	display_name = "oke-igw-${var.cluster_name}"
	enabled = true
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_nat_gateway" "oke_ngw" {
	compartment_id = var.compartment_id
	display_name = "oke-ngw-${var.cluster_name}"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_service_gateway" "oke_sgw" {
	compartment_id = var.compartment_id
	display_name = "oke-sgw-${var.cluster_name}"
	services {
		service_id = "ocid1.service.oc1.eu-madrid-1.aaaaaaaafxkoaua7i6vpniplhcnme6lgi3tymk65mbltlxqfvsxpsdqhzf5a"
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_route_table" "private_route_table" {
	compartment_id = var.compartment_id
	display_name = "oke-private-routetable-${var.cluster_name}"
	route_rules {
		description = "traffic to the internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = "${oci_core_nat_gateway.oke_ngw.id}"
	}
	route_rules {
		description = "traffic to OCI services"
		destination = var.service_cidr_block
		destination_type = "SERVICE_CIDR_BLOCK"
		network_entity_id = "${oci_core_service_gateway.oke_sgw.id}"
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_subnet" "service_lb_subnet" {
	cidr_block = var.lb_subnet_cidr
	compartment_id = var.compartment_id
	display_name = "oke-svclbsubnet-${var.cluster_name}"
	dns_label = "lbsub${random_string.lb_subnet_dns_label.result}"
	prohibit_public_ip_on_vnic = false
	route_table_id = "${oci_core_default_route_table.public_route_table.id}"
	security_list_ids = ["${oci_core_vcn.oke_vcn.default_security_list_id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_subnet" "node_subnet" {
	cidr_block = var.node_subnet_cidr
	compartment_id = var.compartment_id
	display_name = "oke-nodesubnet-${var.cluster_name}"
	dns_label = "sub${random_string.node_subnet_dns_label.result}"
	prohibit_public_ip_on_vnic = true
	route_table_id = "${oci_core_route_table.private_route_table.id}"
	security_list_ids = ["${oci_core_security_list.node_sec_list.id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_subnet" "kubernetes_api_endpoint_subnet" {
	cidr_block = var.api_endpoint_subnet_cidr
	compartment_id = var.compartment_id
	display_name = "oke-k8sApiEndpoint-subnet-${var.cluster_name}"
	dns_label = "sub${random_string.api_subnet_dns_label.result}"
	prohibit_public_ip_on_vnic = false
	route_table_id = "${oci_core_default_route_table.public_route_table.id}"
	security_list_ids = ["${oci_core_security_list.kubernetes_api_endpoint_sec_list.id}"]
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_default_route_table" "public_route_table" {
	display_name = "oke-public-routetable-${var.cluster_name}"
	route_rules {
		description = "traffic to/from internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		network_entity_id = "${oci_core_internet_gateway.oke_igw.id}"
	}
	manage_default_resource_id = "${oci_core_vcn.oke_vcn.default_route_table_id}"
	freeform_tags = local.common_tags
}

resource "oci_core_security_list" "service_lb_sec_list" {
	compartment_id = var.compartment_id
	display_name = "oke-svclbseclist-${var.cluster_name}"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_security_list" "node_sec_list" {
	compartment_id = var.compartment_id
	display_name = "oke-nodeseclist-${var.cluster_name}"
	egress_security_rules {
		description = "Allow pods on one worker node to communicate with pods on other worker nodes"
		destination = var.node_subnet_cidr
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = false
	}
	egress_security_rules {
		description = "Access to Kubernetes API Endpoint"
		destination = var.api_endpoint_subnet_cidr
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = false
	}
	egress_security_rules {
		description = "Kubernetes worker to control plane communication"
		destination = var.api_endpoint_subnet_cidr
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = false
	}
	egress_security_rules {
		description = "Path discovery"
		destination = var.api_endpoint_subnet_cidr
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = false
	}
	egress_security_rules {
		description = "Allow nodes to communicate with OKE to ensure correct start-up and continued functioning"
		destination = var.service_cidr_block
		destination_type = "SERVICE_CIDR_BLOCK"
		protocol = "6"
		stateless = false
	}
	egress_security_rules {
		description = "ICMP Access from Kubernetes Control Plane"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = false
	}
	egress_security_rules {
		description = "Worker Nodes access to Internet"
		destination = "0.0.0.0/0"
		destination_type = "CIDR_BLOCK"
		protocol = "all"
		stateless = false
	}
	ingress_security_rules {
		description = "Allow pods on one worker node to communicate with pods on other worker nodes"
		protocol = "all"
		source = var.node_subnet_cidr
		stateless = false
	}
	ingress_security_rules {
		description = "Path discovery"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = var.api_endpoint_subnet_cidr
		stateless = false
	}
	ingress_security_rules {
		description = "TCP access from Kubernetes Control Plane"
		protocol = "6"
		source = var.api_endpoint_subnet_cidr
		stateless = false
	}
	ingress_security_rules {
		description = "Inbound SSH traffic to worker nodes"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = false
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_core_security_list" "kubernetes_api_endpoint_sec_list" {
	compartment_id = var.compartment_id
	display_name = "oke-k8sApiEndpoint-${var.cluster_name}"
	egress_security_rules {
		description = "Allow Kubernetes Control Plane to communicate with OKE"
		destination = var.service_cidr_block
		destination_type = "SERVICE_CIDR_BLOCK"
		protocol = "6"
		stateless = false
	}
	egress_security_rules {
		description = "All traffic to worker nodes"
		destination = var.node_subnet_cidr
		destination_type = "CIDR_BLOCK"
		protocol = "6"
		stateless = false
	}
	egress_security_rules {
		description = "Path discovery"
		destination = var.node_subnet_cidr
		destination_type = "CIDR_BLOCK"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		stateless = false
	}
	ingress_security_rules {
		description = "External access to Kubernetes API endpoint"
		protocol = "6"
		source = "0.0.0.0/0"
		stateless = false
	}
	ingress_security_rules {
		description = "Kubernetes worker to Kubernetes API endpoint communication"
		protocol = "6"
		source = var.node_subnet_cidr
		stateless = false
	}
	ingress_security_rules {
		description = "Kubernetes worker to control plane communication"
		protocol = "6"
		source = var.node_subnet_cidr
		stateless = false
	}
	ingress_security_rules {
		description = "Path discovery"
		icmp_options {
			code = "4"
			type = "3"
		}
		protocol = "1"
		source = var.node_subnet_cidr
		stateless = false
	}
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
	freeform_tags = local.common_tags
}

resource "oci_containerengine_cluster" "oke_cluster" {
	cluster_pod_network_options {
		cni_type = "OCI_VCN_IP_NATIVE"
	}
	compartment_id = var.compartment_id
	endpoint_config {
		is_public_ip_enabled = true
		subnet_id = "${oci_core_subnet.kubernetes_api_endpoint_subnet.id}"
	}
	freeform_tags = local.common_tags
	kubernetes_version = var.kubernetes_version
	name = var.cluster_name
	options {
		admission_controller_options {
			is_pod_security_policy_enabled = false
		}
		persistent_volume_config {
			freeform_tags = local.common_tags
		}
		service_lb_config {
			freeform_tags = local.common_tags
		}
		service_lb_subnet_ids = ["${oci_core_subnet.service_lb_subnet.id}"]
	}
	type = "BASIC_CLUSTER"
	vcn_id = "${oci_core_vcn.oke_vcn.id}"
}

resource "oci_containerengine_node_pool" "oke_node_pool" {
	cluster_id = "${oci_containerengine_cluster.oke_cluster.id}"
	compartment_id = var.compartment_id
	freeform_tags = merge(local.common_tags, {
		"OKEnodePoolName" = "pool1"
	})
	initial_node_labels {
		key = "name"
		value = var.cluster_name
	}
	kubernetes_version = var.kubernetes_version
	name = "pool1"
	node_config_details {
		freeform_tags = merge(local.common_tags, {
			"OKEnodePoolName" = "pool1"
		})
		node_pool_pod_network_option_details {
			cni_type = "OCI_VCN_IP_NATIVE"
		}
		placement_configs {
			availability_domain = var.availability_domain
			subnet_id = "${oci_core_subnet.node_subnet.id}"
		}
		size = var.node_pool_size
	}
	node_eviction_node_pool_settings {
		eviction_grace_duration = "PT60M"
	}
	node_shape = var.node_shape
	node_shape_config {
		memory_in_gbs = var.node_memory_in_gbs
		ocpus = var.node_ocpus
	}
	node_source_details {
		image_id = var.node_image_id
		source_type = "IMAGE"
	}
}

resource "random_string" "lb_subnet_dns_label" {
	length = 8
	special = false
	lower = true
	upper = false
	numeric = true
}

resource "random_string" "node_subnet_dns_label" {
	length = 8
	special = false
	lower = true
	upper = false
	numeric = true
}

resource "random_string" "api_subnet_dns_label" {
	length = 8
	special = false
	lower = true
	upper = false
	numeric = true
}
