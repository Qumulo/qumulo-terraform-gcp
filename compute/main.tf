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

module "compute" {
  source = "./module/"

  gce_image_name                    = var.gce_image_name
  gce_ssh_public_key_path           = var.gce_ssh_public_key_path
  gcp_project_id                    = var.gcp_project_id
  gcp_region                        = var.gcp_region
  gcp_subnet_name                   = var.gcp_subnet_name
  gcp_vpc_name                      = var.gcp_vpc_name
  gcp_zones                         = var.gcp_zones
  gcp_cluster_custom_role           = var.gcp_cluster_custom_role
  gcp_provisioner_custom_role       = var.gcp_provisioner_custom_role
  gcs_bucket_name                   = var.gcs_bucket_name
  gcs_bucket_prefix                 = var.gcs_bucket_prefix
  gcs_bucket_region                 = var.gcs_bucket_region
  check_provisioner_shutdown        = var.check_provisioner_shutdown
  deployment_name                   = var.deployment_name
  dev_environment                   = var.dev_environment
  kms_key_name                      = var.kms_key_name
  q_boot_dkv_type                   = var.q_boot_dkv_type
  q_boot_drive_size                 = var.q_boot_drive_size
  q_cluster_admin_password          = var.q_cluster_admin_password
  q_cluster_floating_ips            = var.q_cluster_floating_ips
  q_cluster_fw_ingress_cidrs        = var.q_cluster_fw_ingress_cidrs
  q_cluster_name                    = var.q_cluster_name
  q_cluster_nexus_registration_key  = var.q_cluster_nexus_registration_key
  q_cluster_version                 = var.q_cluster_version
  q_debian_package                  = var.q_debian_package
  q_existing_deployment_unique_name = var.q_existing_deployment_unique_name
  q_instance_type                   = var.q_instance_type
  q_node_count                      = var.q_node_count
  q_package_url                     = var.q_package_url
  q_persistent_storage_type         = var.q_persistent_storage_type
  q_replacement_cluster             = var.q_replacement_cluster
  q_target_node_count               = var.q_target_node_count
  q_write_cache_tput                = var.q_write_cache_tput
  q_write_cache_type                = var.q_write_cache_type
  q_write_cache_iops                = var.q_write_cache_iops
  term_protection                   = var.term_protection
  labels                            = var.labels

  persistent_storage_output = local.persistent_storage_output.outputs_persistent_storage

  providers = {
    google.bucket = google.bucket
  }
}

output "outputs_compute" {
  value = module.compute
}
