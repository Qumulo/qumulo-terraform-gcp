#MIT License

#Copyright (c) 2025 Qumulo, Inc.

#Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions =

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
  #Validate the persistent storage is in the same region as the cluster
  valid_qps_region = var.gcp_region == var.persistent_storage_bucket_region

  #Find the number of AZs desired
  number_azs = length(var.gcp_zones)
  maz        = local.number_azs > 1
  saz        = !local.maz

  #Multi-AZ validation
  valid_number_azs = local.number_azs == 1 || local.number_azs == 3

  valid_maz_majority_quorum        = local.number_azs == 1 || local.number_azs == 3 && (var.node_count == 3 || var.node_count > 4)
  valid_maz_majority_quorum_target = var.target_node_count == null || var.replacement_cluster ? true : (var.target_node_count < var.node_count && local.number_azs == 3 ? var.target_node_count == 3 || var.target_node_count > 4 : true)

  #Calculate max nodes per AZ for MAZ deployment
  nodes_per_az = ceil(var.node_count / local.number_azs)

  #create the fault domains per AZ
  private_fault_domain_id_per_az = local.maz ? range(1, local.number_azs + 1) : [for i in range(var.node_count) : "none"]

  #Build the full list of gcp zones and fault domains for every node
  gcp_zone_per_node_full = local.maz ? flatten([
    for i in range(local.nodes_per_az) : var.gcp_zones]) : flatten([
  for i in range(var.node_count) : var.gcp_zones])

  private_fault_domain_id_per_node_full = flatten([
  for i in range(local.nodes_per_az) : local.private_fault_domain_id_per_az])

  gcp_zone_per_node = slice(local.gcp_zone_per_node_full, 0, var.node_count)

  private_fault_domain_id_per_node = slice(local.private_fault_domain_id_per_node_full, 0, var.node_count)
}

#Error checking null-resources
resource "null_resource" "check_valid_bucket_region" {
  count = local.valid_qps_region ? 0 : "GCS buckets are deployed in a different region from the cluster.  Align the regions!"
}
resource "null_resource" "check_valid_number_azs" {
  count = local.valid_number_azs ? 0 : "Invalid number of AZs.  Specify 1 zone for a single AZ deployment.  Specify 3 zones for a multi-AZ deployment."
}
resource "null_resource" "check_valid_maz_majority_quorum" {
  count = local.valid_maz_majority_quorum ? 0 : "q_node_count = 4 (or < 3) is not a valid cluster size for a multi-AZ deployment with 3 AZs.  Either use 3 nodes or 5 or more."
}
resource "null_resource" "check_valid_maz_majority_quorum_target" {
  count = local.valid_maz_majority_quorum_target ? 0 : "q_target_node_count = 4 (or < 3) is not a valid cluster size for a multi-AZ deployment with 3 AZs.  Either use 3 nodes or 5 or more."
}
