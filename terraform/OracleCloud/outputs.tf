output "cluster_id" {
  description = "The OCID of the created OKE cluster"
  value       = oci_containerengine_cluster.oke_cluster.id
}

output "vcn_id" {
  description = "The OCID of the VCN"
  value       = oci_core_vcn.oke_vcn.id
}

output "node_pool_id" {
  description = "The OCID of the node pool"
  value       = oci_containerengine_node_pool.oke_node_pool.id
}

output "lb_subnet_id" {
  description = "The OCID of the load balancer subnet"
  value       = oci_core_subnet.service_lb_subnet.id
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig file for the cluster"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.oke_cluster.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0"
} 