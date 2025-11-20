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

# **** Version 1.9 ****

resource "null_resource" "project_lock" {
  triggers = {
    deployment_project = var.gcp_project_id
  }

  lifecycle { ignore_changes = all }
}

resource "null_resource" "region_lock" {
  triggers = {
    deployment_region = var.gcp_region
  }

  lifecycle { ignore_changes = all }
}

resource "null_resource" "instance_type_lock" {
  triggers = {
    deployment_instance_type = var.q_instance_type
  }

  lifecycle { ignore_changes = all }
}

data "google_project" "project" {
  project_id = local.deployment_project
}

data "google_compute_subnetwork" "selected" {
  name    = var.gcp_subnet_name
  project = local.deployment_project
  region  = local.deployment_region
}

locals {
  #Locked variables post initial deployment
  deployment_project       = null_resource.project_lock.triggers.deployment_project
  deployment_region        = null_resource.region_lock.triggers.deployment_region
  deployment_instance_type = null_resource.instance_type_lock.triggers.deployment_instance_type

  #Variables whose value depends on locked variables
  boot_dkv_type      = startswith(local.deployment_instance_type, "n2-") ? "pd-balanced" : var.q_boot_dkv_type
  node_instance_type = ((local.deployment_instance_type == "n2-highmem-4" || local.deployment_instance_type == "n2d-highmem-4") && !var.dev_environment) ? replace(local.deployment_instance_type, "/-4/", "-8") : local.deployment_instance_type
  write_cache_type   = startswith(local.deployment_instance_type, "n2-") ? "pd-ssd" : var.q_write_cache_type

  #local variable for cleaner references in subsequent use
  deployment_name_lower  = lower(var.deployment_name)
  deployment_unique_name = null_resource.name_lock.triggers.deployment_unique_name

  # Outputs from persistent-storage deployment
  persistent_storage                        = var.persistent_storage_output
  persistent_storage_bucket_names           = local.persistent_storage.bucket_names
  persistent_storage_bucket_region          = local.persistent_storage.bucket_region
  persistent_storage_bucket_uris            = local.persistent_storage.bucket_uris
  persistent_storage_capacity_limit         = local.persistent_storage.soft_capacity_limit_bytes
  persistent_storage_deployment_unique_name = local.persistent_storage.deployment_unique_name

  #Paths and Google Cloud Storage prefixes for the provisioning module
  functions_gcs_prefix = "${var.gcs_bucket_prefix}${local.deployment_unique_name}/functions/"
  scripts_path         = "${path.module}/sub-modules/qprovisioner/scripts/"
  state_gcs_prefix     = "${var.gcs_bucket_prefix}${local.deployment_unique_name}"

  #Path for the Qumulo cluster module
  cluster_scripts_path = "${path.module}/sub-modules/qcluster/scripts/"

  #GCS prefix for the Qumulo installer and package******
  install_gcs_prefix      = "${var.gcs_bucket_prefix}qumulo-core-install"
  bucket_package_url_base = "gs://${var.gcs_bucket_name}/${local.install_gcs_prefix}/${var.q_cluster_version}"
  bucket_package_url      = var.q_debian_package ? "${local.bucket_package_url_base}/qumulo-core.deb" : "${local.bucket_package_url_base}/qumulo-core.rpm"
  package_url             = var.q_package_url != null ? var.q_package_url : local.bucket_package_url

  #make list for availability zones
  gcp_zones = tolist(split(",", replace(var.gcp_zones, "/\\s*/", "")))

  #get the state of Private Google Access for the subnet
  gcp_subnet_private_access = data.google_compute_subnetwork.selected.private_ip_google_access
}

resource "null_resource" "private_google_access_is_false" {
  # trigger on every terraform apply
  triggers = {
    always_run = timestamp()
  }
  lifecycle {
    precondition {
      condition     = local.gcp_subnet_private_access
      error_message = "Private Google Access is required to avoid GCS egress charges for subnet=${data.google_compute_subnetwork.selected.name}. Please enable Private Google Access on the subnet."
    }
  }
}

resource "null_resource" "deploy_provisioner_is_false_in_dev_only" {
  # trigger on every terraform apply
  triggers = {
    always_run = timestamp()
  }
  lifecycle {
    precondition {
      condition     = var.dev_environment || var.deploy_provisioner
      error_message = "Setting deploy_provisioner to false is allowed in development environment only"
    }
  }
}

#Generates an 7 digit random alphanumeric for the deployment_unique_name.  Generated on first apply and never changes.
resource "random_string" "alphanumeric" {
  length      = 7
  lower       = true
  min_lower   = 3
  min_numeric = 2
  numeric     = true
  special     = false
  upper       = false
  keepers = {
    name = local.deployment_name_lower
  }
  lifecycle { ignore_changes = all }
}

#This  resource is used to 'lock' the deployment_unique_name.  Any changes to the deployment_name after the first apply are ignored.
#Appends the random alpha numeric to the deployment name.  All resources are labeled/named with this unique name.
resource "null_resource" "name_lock" {
  triggers = {
    deployment_unique_name = "${local.deployment_name_lower}-${random_string.alphanumeric.id}"
  }

  lifecycle { ignore_changes = all }
}

# Copy shared Python installer script used by both cluster nodes and provisioner
resource "google_storage_bucket_object" "shared_vm_scripts" {
  provider       = google.bucket
  bucket         = var.gcs_bucket_name
  for_each       = fileset("${path.module}/shared/vm-scripts/", "python_installer.sh")
  name           = "${local.functions_gcs_prefix}${each.value}"
  source         = "${path.module}/shared/vm-scripts/${each.value}"
  source_md5hash = filemd5("${path.module}/shared/vm-scripts/${each.value}")
}

# Copy cluster node initialization script (user-data.py)
resource "google_storage_bucket_object" "qcluster_python" {
  provider       = google.bucket
  bucket         = var.gcs_bucket_name
  for_each       = fileset("${path.module}/sub-modules/qcluster/scripts/", "user-data.py")
  name           = "${local.functions_gcs_prefix}${each.value}"
  source         = "${path.module}/sub-modules/qcluster/scripts/${each.value}"
  source_md5hash = filemd5("${path.module}/sub-modules/qcluster/scripts/${each.value}")
}

# Copy provisioner-specific scripts: Python dependencies installer, requirements, and Firestore client
resource "google_storage_bucket_object" "qprovisioner_python" {
  provider       = google.bucket
  bucket         = var.gcs_bucket_name
  for_each       = fileset("${path.module}/sub-modules/qprovisioner/scripts/", "{install_vm_deps.sh,requirements.txt,firestore_vm.py}")
  name           = "${local.functions_gcs_prefix}${each.value}"
  source         = "${path.module}/sub-modules/qprovisioner/scripts/${each.value}"
  source_md5hash = filemd5("${path.module}/sub-modules/qprovisioner/scripts/${each.value}")
}

#This sub-module stores Qumulo admin credentials and HMAC keys in GCP Secrets Manager.
module "secrets" {
  source = "./sub-modules/secrets"

  gcp_region             = local.deployment_region
  cluster_admin_password = var.q_cluster_admin_password
  deployment_unique_name = local.deployment_unique_name
  gcp_project_id         = local.deployment_project

  labels = var.labels
}

#This sub-module validates and error checks subnets and AZ variables.  It establishes the final configuration variables for the cluster.
module "qconfig" {
  source = "./sub-modules/qconfig"

  gcp_region                       = local.deployment_region
  gcp_subnet_cidr                  = data.google_compute_subnetwork.selected.ip_cidr_range
  gcp_zones                        = local.gcp_zones
  node_count                       = var.q_node_count
  persistent_storage_bucket_region = local.persistent_storage_bucket_region
  replacement_cluster              = var.q_replacement_cluster
  target_node_count                = var.q_target_node_count
}

#This sub-module builds the Qumulo Cluster consisting of GCE instances, persistent disk volumes, and GCS buckets.
#Firewall rules are built for the cluster, a service account is created, and IAM roles are also built for the cluster.
module "qcluster" {
  source = "./sub-modules/qcluster"

  gce_image_name                            = var.gce_image_name
  gce_ssh_public_key_path                   = var.gce_ssh_public_key_path
  gcp_cluster_custom_role                   = var.gcp_cluster_custom_role
  gcp_number_azs                            = module.qconfig.number_azs
  gcp_project_id                            = local.deployment_project
  gcp_project_number                        = data.google_project.project.number
  gcp_region                                = local.deployment_region
  gcp_subnet_name                           = var.gcp_subnet_name
  gcp_vpc_name                              = var.gcp_vpc_name
  gcp_zone_per_node                         = module.qconfig.gcp_zone_per_node
  gcs_bucket_name                           = var.gcs_bucket_name
  functions_gcs_prefix                      = local.functions_gcs_prefix
  boot_dkv_type                             = local.boot_dkv_type
  boot_drive_size                           = var.q_boot_drive_size
  cluster_floating_ips                      = var.q_cluster_floating_ips
  cluster_fw_ingress_cidrs                  = var.q_cluster_fw_ingress_cidrs == null ? tolist([data.google_compute_subnetwork.selected.ip_cidr_range]) : concat([data.google_compute_subnetwork.selected.ip_cidr_range], tolist(split(",", replace(var.q_cluster_fw_ingress_cidrs, "/\\s*/", ""))))
  cluster_name                              = var.q_cluster_name
  cluster_persistent_storage_capacity_limit = local.persistent_storage_capacity_limit
  cluster_scripts_path                      = local.cluster_scripts_path
  debian_package                            = var.q_debian_package
  qumulo_package_url                        = local.package_url
  deployment_unique_name                    = local.deployment_unique_name
  existing_deployment_unique_name           = var.q_existing_deployment_unique_name
  install_qumulo_package                    = var.deploy_provisioner
  instance_type                             = local.node_instance_type
  kms_key_name                              = var.kms_key_name
  node_count                                = var.q_node_count
  persistent_bucket_names                   = local.persistent_storage_bucket_names
  persistent_storage_deployment_unique_name = local.persistent_storage_deployment_unique_name
  replacement_cluster                       = var.q_replacement_cluster
  target_node_count                         = var.q_target_node_count
  term_protection                           = var.term_protection
  write_cache_iops                          = var.q_write_cache_iops
  write_cache_tput                          = var.q_write_cache_tput
  write_cache_type                          = local.write_cache_type

  labels = var.labels
}

#This sub-module instantiates an GCE instance for configuration of the Qumulo Cluster and is then shutdown.
#Floating IPs, admin password, GCE labels, termination protection, and GCS storage class are all configured.
#Until Terraform supports user data updates without destroying the instance, this instance will get destroyed
#and recreated on subsequent applies.  It is built for this as all state is stored in GCP Firestore.
module "qprovisioner" {
  count  = var.deploy_provisioner ? 1 : 0
  source = "./sub-modules/qprovisioner"

  gcp_project_id                                    = local.deployment_project
  gcp_project_number                                = data.google_project.project.number
  gcp_provisioner_custom_role                       = var.gcp_provisioner_custom_role
  gcp_region                                        = local.deployment_region
  gcp_subnet_name                                   = var.gcp_subnet_name
  gcp_vpc_name                                      = var.gcp_vpc_name
  gcp_number_azs                                    = module.qconfig.number_azs
  gcp_zone                                          = module.qconfig.gcp_zone_per_node[0]
  gcs_bucket_name                                   = var.gcs_bucket_name
  boot_type                                         = "pd-balanced"
  check_provisioner_shutdown                        = var.check_provisioner_shutdown
  cluster_fault_domain_ids                          = module.qconfig.private_fault_domain_id_per_node
  cluster_floating_ips                              = module.qcluster.floating_ips
  cluster_fw_ingress_cidrs                          = var.q_cluster_fw_ingress_cidrs == null ? tolist([data.google_compute_subnetwork.selected.ip_cidr_range]) : concat([data.google_compute_subnetwork.selected.ip_cidr_range], tolist(split(",", replace(var.q_cluster_fw_ingress_cidrs, "/\\s*/", ""))))
  cluster_instance_ids                              = module.qcluster.instance_ids
  cluster_name                                      = var.q_cluster_name
  cluster_node1_ip                                  = module.qcluster.node1_ip
  cluster_persistent_bucket_names                   = local.persistent_storage_bucket_names
  cluster_persistent_bucket_uris                    = local.persistent_storage_bucket_uris
  cluster_persistent_storage_capacity_limit         = local.persistent_storage_capacity_limit
  cluster_persistent_storage_deployment_unique_name = local.persistent_storage_deployment_unique_name
  cluster_persistent_storage_type                   = var.q_persistent_storage_type
  cluster_primary_ips                               = module.qcluster.primary_ips
  cluster_secrets_name                              = module.secrets.cluster_secrets_name
  cluster_temporary_password                        = module.qcluster.temporary_password
  deployment_unique_name                            = local.deployment_unique_name
  existing_deployment_unique_name                   = var.q_existing_deployment_unique_name
  flash_iops                                        = module.qcluster.write_cache_iops == null ? 0 : module.qcluster.write_cache_iops
  flash_tput                                        = module.qcluster.write_cache_tput == null ? 0 : module.qcluster.write_cache_tput
  functions_gcs_prefix                              = local.functions_gcs_prefix
  install_gcs_prefix                                = local.install_gcs_prefix
  instance_type                                     = "n2-standard-2"
  kms_key_name                                      = var.kms_key_name
  qumulo_package_url                                = local.package_url
  replacement_cluster                               = var.q_replacement_cluster
  target_node_count                                 = var.q_target_node_count == null ? length(module.qcluster.primary_ips) : var.q_target_node_count
  scripts_path                                      = local.scripts_path
  subnet_cidr                                       = module.qcluster.subnet_cidr
  tun_refill_IOPS                                   = module.qcluster.refill_IOPS
  tun_refill_Bps                                    = module.qcluster.refill_Bps
  tun_disk_count                                    = module.qcluster.disk_count
  dev_environment                                   = var.dev_environment

  labels = var.labels
}
