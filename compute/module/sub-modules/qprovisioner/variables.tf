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

variable "gcp_number_azs" {
  description = "GCP Number of AZs"
  type        = number
}
variable "gcp_project_id" {
  description = "GCP project"
  type        = string
  nullable    = false
}
variable "gcp_project_number" {
  description = "GCP project number"
  type        = string
  nullable    = false
}
variable "gcp_region" {
  description = "GCP region"
  type        = string
  nullable    = false
}
variable "gcp_subnet_name" {
  description = "GCP private subnet name"
  type        = string
  nullable    = false
}
variable "gcp_vpc_name" {
  description = "GCP VPC name"
  type        = string
  nullable    = false
}
variable "gcp_zone" {
  description = "GCP Zone"
  type        = string
}
variable "gcs_bucket_name" {
  description = "GCS bucket name"
  type        = string
}
variable "boot_type" {
  description = "OPTIONAL: Specify the type of EBS for the boot drive"
  type        = string
}
variable "check_provisioner_shutdown" {
  description = "Executes a local-exec script on the Terraform machine to check if the provisioner instance shutdown which indicates a successful cluster deployment."
  type        = bool
}
variable "cluster_fault_domain_ids" {
  description = "List of fault domain IDs for the nodes in the cluster for the Qumulo cluster"
  type        = list(string)
}
variable "cluster_floating_ips" {
  description = "List of floating IPs for the cluster"
  type        = list(string)
}
variable "cluster_fw_ingress_cidrs" {
  description = "GCP firewall ingress source address CIDRs"
  type        = list(string)
}
variable "cluster_instance_ids" {
  description = "List of all GCE instance IDs for the Qumulo cluster"
  type        = list(string)
}
variable "cluster_name" {
  description = "Qumulo cluster name"
  type        = string
}
variable "cluster_nexus_registration_key" {
  description = "Qumulo Nexus Registration Key"
  type        = string
}
variable "cluster_node1_ip" {
  description = "Primary IP for Node 1"
  type        = string
}
variable "cluster_persistent_bucket_names" {
  description = "Qumulo GCS persistent storage bucket names"
  type        = list(string)
}
variable "cluster_persistent_bucket_uris" {
  description = "Qumulo GCS persistent storage bucket URIs"
  type        = list(string)
}
variable "cluster_persistent_storage_capacity_limit" {
  description = "Soft capacity limit for all buckets combined"
  type        = string
}
variable "cluster_persistent_storage_deployment_unique_name" {
  description = "The persistent-storage deployment unique name for GCS buckets"
  type        = string
}
variable "cluster_persistent_storage_type" {
  description = "GCS storage class to persist data in. CNQ Hot uses hot_gcs_std(default).  CNQ Cold is not yet supported."
  type        = string
}
variable "cluster_primary_ips" {
  description = "List of all primary IPs for the Qumulo cluster"
  type        = list(string)
}
variable "cluster_secrets_name" {
  description = "Cluster secrets name"
  type        = string
}
variable "cluster_temporary_password" {
  description = "Temporary password for Qumulo cluster.  Used prior to forming first quorum."
  type        = string
}
variable "deployment_unique_name" {
  description = "Unique Name for this Terraform deployment.  This is the deployment name plus 12 random hex digits that will be used for all resource names where appropriate."
  type        = string
}
variable "existing_deployment_unique_name" {
  description = "OPTIONAL: The deployment_unique_name of the previous deployed cluster you want to replace"
  type        = string
}
variable "flash_iops" {
  description = "OPTIONAL: Specify the iops for gp3 or io2"
  type        = number
}
variable "flash_tput" {
  description = "OPTIONAL: Specify the throughput, in MB/s, for gp3"
  type        = number
}
variable "functions_gcs_prefix" {
  description = "GCS prefix for provisioner functions"
  type        = string
}
variable "install_gcs_prefix" {
  description = "GCS prefix for Qumulo Core package location"
  type        = string
}
variable "instance_type" {
  description = "Qumulo GCE instance type"
  type        = string
}
variable "kms_key_name" {
  description = "OPTIONAL: GCP KMS encryption key resource name (full path)"
  type        = string
  default     = null
}
variable "gcp_provisioner_custom_role" {
  description = "OPTIONAL: Fully-qualified custom role name to use for the provisioner instance (e.g., projects/PROJECT_ID/roles/ROLE_ID). If set, the module will NOT create a custom role and will bind this role instead."
  type        = string
  default     = null
}
variable "qumulo_package_url" {
  description = "A URL accessible to the instances pointing to either the qumulo-core.deb or qumulo-core.rpm for the version of Qumulo you want to install. This may either be a HTTP URL or a gs:// object URL."
  type        = string
  nullable    = false
}
#variable "permissions_boundary" {
#  description = "OPTIONAL: Apply an IAM Permissions Boundary Policy to the Qumulo IAM roles that are created for the provisioning instance. This is an account based policy and is optional. Qumulo's IAM roles conform to the least privilege model."
#  type        = string
#}
variable "replacement_cluster" {
  description = "OPTIONAL: Build a replacement cluster for an existing Terraform deployment.  This requires a new workspace with a separate state file.  This functionality enables in-service changes to the entire compute & cache front-end."
  type        = bool
}
variable "scripts_path" {
  description = "Local path for provisioner scripts"
  type        = string
}
variable "subnet_cidr" {
  description = "CIDR block for the cluster's subnet"
  type        = string
}
variable "target_node_count" {
  description = "The desired node count in the cluster.  Used for removing nodes and shrinking the cluster."
  type        = number
  nullable    = false
}
variable "tun_refill_IOPS" {
  description = "Tunable"
  type        = string
}
variable "tun_refill_Bps" {
  description = "Tunable"
  type        = string
}
variable "tun_disk_count" {
  description = "Tunable"
  type        = string
}
variable "labels" {
  description = "Additional global labels"
  type        = map(string)
}
variable "dev_environment" {
  description = "Disables some checks and restrictions. Leaves the provisioner running after the cluster is deployed. NOT recommended for production"
  type        = bool
}
