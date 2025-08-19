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

output "service_account_id" {
  description = "Service account for the cluster"
  value       = google_service_account.q_access.id
}
output "nodes" {
  description = "Properties of the nodes in the Qumulo cluster"
  value = [
    for node in google_compute_instance.node : {
      id          = node.id
      instance_id = node.instance_id
      primary_ip  = node.network_interface.0.network_ip
    }
  ]
}
output "instance_ids" {
  description = "List of all GCE instance IDs for the Qumulo cluster"
  value       = flatten(concat(google_compute_instance.node[*].instance_id))
}
output "node1_ip" {
  description = "Primary IP for Node 1"
  value       = google_compute_instance.node[0].network_interface.0.network_ip
}
output "floating_ips" {
  description = "Floating IPs belonging to the cluster"
  value       = sort([for i in google_compute_address.floating : i.address])
}
output "subnet_cidr" {
  description = "CIDR block for the cluster's subnet"
  value       = data.google_compute_subnetwork.selected.ip_cidr_range
}
output "node_names" {
  description = "Name tags for nodes (EC2 Instances)"
  value       = concat(google_compute_instance.node[*].labels.name)
}
output "primary_ips" {
  description = "List of all primary IPs for the Qumulo cluster"
  value       = flatten(concat(google_compute_instance.node[*].network_interface.0.network_ip))
}
output "temporary_password" {
  description = "Temporary password for Qumulo cluster.  Used prior to forming first quorum."
  value       = tostring(google_compute_instance.node[0].instance_id)
}
output "url" {
  description = "Link to node 1 in the cluster"
  value       = "https://${tostring(google_compute_instance.node[0].network_interface.0.network_ip)}"
}
output "write_cache_iops" {
  description = "Flash IOPS"
  value       = local.write_cache_iops
}
output "write_cache_tput" {
  description = "Flash throughput"
  value       = local.write_cache_tput
}
output "refill_IOPS" {
  description = "tunable"
  value       = local.refill_IOPS
}
output "refill_Bps" {
  description = "tunable"
  value       = local.refill_Bps
}
output "disk_count" {
  description = "tunable"
  value       = local.disk_count
}
