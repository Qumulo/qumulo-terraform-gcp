#MIT License

#Copyright (c) 2025 Qumulo, Inc.

#Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

output "cluster_provisioned" {
  description = "If the qprovisioner module completed secondary provisioning of the cluster = Success/Failure"
  value       = var.deploy_provisioner ? module.qprovisioner[0].status : null
}

output "deployment_unique_name" {
  description = "The unique name for this Cloud Native Qumulo deployment"
  value       = local.deployment_unique_name
}

output "persistent_storage_bucket_names" {
  description = "The GCS bucket names the cluster uses for persistent storage"
  value       = local.persistent_storage_bucket_names
}

output "qumulo_floating_ips" {
  description = "Qumulo floating IPs for IP failover & load distribution.  Use these IPs for the A-records in your DNS."
  value       = var.deploy_provisioner ? module.qprovisioner[0].floating_ips : module.qcluster.floating_ips
}

output "qumulo_primary_ips" {
  description = "Qumulo primary IPs"
  value       = var.deploy_provisioner ? module.qprovisioner[0].primary_ips : null
}

output "qumulo_removed_nodes_primary_ips" {
  description = "Qumulo primary IPs of removed nodes"
  value       = var.deploy_provisioner && module.qprovisioner[0].cleanup ? module.qprovisioner[0].cleanup_nodes : null
}

output "qumulo_removed_nodes_cleanup" {
  description = "Reminder to cleanup unused resources"
  value       = var.deploy_provisioner && module.qprovisioner[0].cleanup ? "Set q_target_node_count=null, decrease q_node_count=<# of nodes in cluster>, tf apply to destroy unused resources" : null
}

output "qumulo_private_url_node1" {
  description = "Link to private IP for Qumulo Cluster - Node 1"
  value       = module.qcluster.url
}

output "qumulo_nodes" {
  description = "Properties of the nodes in the Qumulo cluster"
  value       = var.dev_environment ? module.qcluster.nodes : null
}

output "provisioner" {
  description = "Provisioner instance"
  value       = var.deploy_provisioner ? module.qprovisioner[0].provisioner : null
}
