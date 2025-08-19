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

locals {
  final_node_count    = var.target_node_count
  deployed_node_count = length(var.cluster_primary_ips)
  cleanup             = var.check_provisioner_shutdown ? local.final_node_count < local.deployed_node_count : false
  cleanup_nodes       = local.cleanup ? join(", ", slice(var.cluster_primary_ips, local.final_node_count, local.deployed_node_count)) : null
  provisioner         = google_compute_instance.provisioner
}

output "cleanup" {
  description = "If nodes were removed from the cluster and now need to be subsequently destroyed"
  value       = local.cleanup
}

output "cleanup_nodes" {
  description = "List of nodes were removed from the cluster and now need to be subsequently destroyed"
  value       = local.cleanup_nodes
}

output "floating_ips" {
  description = "Floating IPs for the Qumulo Cluster"
  value       = local.all_floating_ips
}

output "primary_ips" {
  description = "Primary IPs for the Qumulo Cluster"
  value       = slice(var.cluster_primary_ips, 0, local.final_node_count)
}

output "status" {
  description = "If the provisioner instance completed secondary provisioning of the cluster = Success/Failure"
  value       = var.check_provisioner_shutdown ? data.external.provisioner.result["value"] == "Shutting down provisioning instance" ? "Success" : "FAILURE" : "Validate secondary provisioning of the cluster completed.  Verify GCE Instance ID ${google_compute_instance.provisioner.id} auto shutdown or check Firestore https://firestore.googleapis.com/v1/projects/${var.gcp_project}/databases/${var.cluster_persistent_storage_deployment_unique_name}/documents/${var.deployment_unique_name}/last-run-status}"
}

output "provisioner" {
  description = "Provisioner instance"
  value       = {
    name       = local.provisioner.name
    private_ip = local.provisioner.network_interface.0.network_ip
  }
}
