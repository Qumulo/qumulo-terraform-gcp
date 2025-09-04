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

variable "gce_image_name" {
  description = "GCE Image Name"
  type        = string
  nullable    = true
}
variable "gce_ssh_public_key_path" {
  description = "OPTIONAL: The local path to a file containing the public key which should be authorized to ssh into the Qumulo nodes"
  type        = string
  default     = null
}
variable "gcp_project" {
  description = "GCP project"
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
variable "gcp_zones" {
  description = "GCP zones, on or three as a comma delimited string"
  type        = string
  nullable    = false
}
variable "gcp_cluster_custom_role" {
  description = "OPTIONAL: Fully-qualified custom role name to use for cluster instances (e.g., projects/PROJECT_ID/roles/ROLE_ID). If set, the module will NOT create a custom role and will bind this role instead."
  type        = string
  default     = null
  validation {
    condition     = var.gcp_cluster_custom_role == null || can(regex("^projects/[^/]+/roles/[^/]+$", var.gcp_cluster_custom_role))
    error_message = "If set, gcp_cluster_custom_role must be a fully-qualified custom role like projects/PROJECT_ID/roles/ROLE_ID."
  }
}
variable "gcp_provisioner_custom_role" {
  description = "OPTIONAL: Fully-qualified custom role name to use for the provisioner instance (e.g., projects/PROJECT_ID/roles/ROLE_ID). If set, the module will NOT create a custom role and will bind this role instead."
  type        = string
  default     = null
  validation {
    condition     = var.gcp_provisioner_custom_role == null || can(regex("^projects/[^/]+/roles/[^/]+$", var.gcp_provisioner_custom_role))
    error_message = "If set, gcp_provisioner_custom_role must be a fully-qualified custom role like projects/PROJECT_ID/roles/ROLE_ID."
  }
}
variable "gcs_bucket_name" {
  description = "GCP bucket name"
  type        = string
  nullable    = false
}
variable "gcs_bucket_prefix" {
  description = "GCP bucket prefix (path).  Include a trailing slash (/)"
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^.*/$", var.gcs_bucket_prefix))
    error_message = "The gcs_bucket_prefix must end with a /"
  }
}
variable "gcs_bucket_region" {
  description = "GCP region the GCS bucket is hosted in"
  type        = string
  nullable    = false
}
variable "check_provisioner_shutdown" {
  description = "Executes a local-exec script on the Terraform machine to check if the provisioner instance shutdown which indicates a successful cluster deployment."
  type        = bool
  default     = true
}
variable "deployment_name" {
  description = "Name for this Terraform deployment.  This name plus 7 random alphanumeric digits will be used for all resource names where appropriate."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9A-Za-z\\-]{2,18}$", var.deployment_name))
    error_message = "The deployment_name must be a <=18 characters long and use 0-9 A-Z a-z or dash (-)."
  }
}
variable "dev_environment" {
  description = "Disables some checks and restrictions. Leaves the provisioner running after the cluster is deployed. NOT recommended for production"
  type        = bool
  default     = false
}
variable "kms_key_name" {
  description = "OPTIONAL: GCP KMS encryption key resource name (full path)"
  type        = string
  default     = null
}
variable "q_boot_dkv_type" {
  description = "OPTIONAL: Specify the type of Disk for the boot drive and dkv drives"
  type        = string
  default     = "hyperdisk-balanced"
  validation {
    condition = anytrue([
      var.q_boot_dkv_type == "hyperdisk-balanced",
      var.q_boot_dkv_type == "pd-balanced"
    ])
    error_message = "An invalid Disk type was specified. Must be hyperdisk-balanced or pd-ssd."
  }
}
variable "q_boot_drive_size" {
  description = "Size of the boot drive for each Qumulo Instance"
  type        = number
  nullable    = false
  default     = 256
}
variable "q_cluster_admin_password" {
  description = "Qumulo cluster admin password"
  type        = string
  sensitive   = true
  nullable    = false
  validation {
    condition     = can(regex("^(.{0,7}|[^0-9]*|[^A-Z]*|[^a-z]*|[a-zA-Z0-9]*)$", var.q_cluster_admin_password)) ? false : true
    error_message = "The q_cluster_admin_password must be at least 8 characters and contain an uppercase, lowercase, number, and special character."
  }
}
variable "q_cluster_floating_ips" {
  description = "The number of floating ips associated with the Qumulo cluster."
  type        = number
  default     = 12
  validation {
    condition     = var.q_cluster_floating_ips == 0 || (var.q_cluster_floating_ips >= var.q_node_count)
    error_message = "The number of floating ips must be at least the number of nodes. Set to 0 for no floating IPs."
  }
}
variable "q_cluster_fw_ingress_cidrs" {
  description = "OPTIONAL: GCP additional firewall ingress CIDRs for the Qumulo cluster"
  type        = string
  default     = null
  validation {
    condition     = var.q_cluster_fw_ingress_cidrs == null || can(regex("^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/(3[0-2]|[1-2][0-9]|[0-9])))[,]\\s*)*((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/(3[0-2]|[1-2][0-9]|[0-9])))$", var.q_cluster_fw_ingress_cidrs))
    error_message = "The q_cluster_fw_ingress_cidrs must be a valid comma delimited string of CIDRS of the form '10.0.1.0/24, 10.10.3.0/24, 172.16.30.0/24'."
  }
}
variable "q_cluster_name" {
  description = "Qumulo cluster name"
  type        = string
  default     = "CNQ"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9\\-]{0,13}[a-zA-Z0-9]$", var.q_cluster_name))
    error_message = "The q_cluster_name must be an alphanumeric string between 2 and 15 characters. Dash (-) is allowed if not the first or last character."
  }
}
variable "q_cluster_version" {
  description = "Qumulo cluster software version"
  type        = string
  default     = "7.5.0"
  validation {
    condition     = can(regex("^((4\\.[2-3]\\.[0-9][0-9]?\\.?[0-9]?[0-9]?)|([5-9][0-9]?\\.[0-9]\\.[0-9][a-zA-Z0-9]?\\.?[0-9]?[a-zA-Z0-9]?))$", var.q_cluster_version))
    error_message = "The q_cluster_version 7.6.0 or greater. Examples: 7.6.0.1, 7.6.1, 7.7.0, etc."
  }
}
variable "q_debian_package" {
  description = "Debian or RHL package"
  type        = bool
  default     = true
}
variable "q_existing_deployment_unique_name" {
  description = "OPTIONAL: The deployment_unique_name of the previous deployed cluster you want to replace"
  type        = string
  default     = null
  validation {
    condition     = var.q_existing_deployment_unique_name == null || can(regex("^[0-9a-z\\-]{2,30}$", var.q_existing_deployment_unique_name))
    error_message = "The deployment_name must be a <=30 characters long and use 0-9 a-z or dash (-). Copy from previous deployment Terraform workspace output."
  }
}
#variable "q_fqdn_name" {
#  description = "OPTIONAL: The Fully Qualified Domain Name (FQDN) for Route 53 Private Hosted Zone "
#  type        = string
#  default     = null
#  validation {
#    condition     = var.q_fqdn_name == null || can(regex("^[0-9A-Za-z\\.\\-]*$", var.q_fqdn_name))
#    error_message = "The q_fqdn_name may only contain alphanumeric values and dashes (-) and/or dots (.)."
#  }
#}
variable "q_instance_type" {
  description = "Qumulo GCP compute engine instance type"
  type        = string
  default     = "n2-highmem-16"
  nullable    = false
  validation {
    condition = anytrue([
      var.q_instance_type == "z3-highmem-14-standardlssd",
      var.q_instance_type == "z3-highmem-22-standardlssd",
      var.q_instance_type == "z3-highmem-44-standardlssd",
      var.q_instance_type == "z3-highmem-8-highlssd",
      var.q_instance_type == "z3-highmem-16-highlssd",
      var.q_instance_type == "z3-highmem-22-highlssd",
      var.q_instance_type == "z3-highmem-32-highlssd",
      var.q_instance_type == "z3-highmem-44-highlssd",
      var.q_instance_type == "n2-highmem-8",
      var.q_instance_type == "n2-highmem-16",
      var.q_instance_type == "n2-highmem-32",
      var.q_instance_type == "n2-highmem-48",
      var.q_instance_type == "n2d-highmem-8",
      var.q_instance_type == "n2d-highmem-16",
      var.q_instance_type == "n2d-highmem-32",
      var.q_instance_type == "n2d-highmem-48"
    ])
    error_message = "Only n2-highmem and n2d-highmem instance types are supported.  Must be >=n2-highmem-8 or >=n2d-highmem-8."
  }
}
variable "q_node_count" {
  description = "Qumulo cluster node count"
  type        = number
  default     = 3
  validation {
    condition     = var.q_node_count == 1 || (var.q_node_count >= 3 && var.q_node_count <= 24)
    error_message = "The q_node_count value is mandatory.  It is also used to grow a cluster. Specify 3 to 24 nodes or 1 node."
  }
}
variable "q_package_url" {
  description = "A URL accessible to the instances pointing to the qumulo-core.deb or qumulo-core.rpm for the version of Qumulo you want to install. If null, default to using the package in the bucket specified by gcs_bucket_name and gcs_bucket_prefix."
  type        = string
  nullable    = true
  default     = null
  validation {
    condition = var.q_package_url == null ? true : anytrue([
      can(regex("^https?://.*$", var.q_package_url)),
      can(regex("^gs://.*$", var.q_package_url)),
    ])
    error_message = "The q_package_url must be an http(s):// or gs:// URL."
  }
}
variable "q_persistent_storage_type" {
  description = "GCS storage class to persist data in. CNQ Hot uses hot_gcs_std."
  type        = string
  default     = "hot_gcs_std"
  nullable    = false
  validation {
    condition = anytrue([
      var.q_persistent_storage_type == "hot_gcs_std",
    ])
    error_message = "CNQ Hot uses hot_gcs_std."
  }
}
variable "q_replacement_cluster" {
  description = "OPTIONAL: Build a replacement cluster for an existing Terraform deployment.  This requires a new workspace with a separate state file.  This functionality enables in-service changes to the entire compute & cache front-end."
  type        = bool
  default     = false
}
variable "q_target_node_count" {
  description = "Qumulo cluster target node count"
  type        = number
  default     = null
  nullable    = true
  validation {
    condition     = var.q_target_node_count == null || can(var.q_target_node_count == 1 || (var.q_target_node_count >= 3 && var.q_target_node_count <= 23))
    error_message = "The q_target_node_count value is used to shrink the cluster.  Specify 3 to 23 nodes or 1 node. It must be less than q_node_count to take effect."
  }
}
variable "q_write_cache_tput" {
  description = "OPTIONAL: Specify the throughput, in MB/s, for hyper-disk, 140 to 2400 MB/s"
  type        = number
  default     = null
  validation {
    condition     = var.q_write_cache_tput == null || can(var.q_write_cache_tput >= 140 && var.q_write_cache_tput <= 2400)
    error_message = "Balanced persistent disk throughput must be in the range of 140 to 2400 MB/s."
  }
}
variable "q_write_cache_type" {
  description = "OPTIONAL: Specify the type of disk to use."
  type        = string
  default     = "hyperdisk-balanced"
  validation {
    condition = anytrue([
      var.q_write_cache_type == "hyperdisk-balanced",
      var.q_write_cache_type == "pd-ssd"
    ])
    error_message = "An invalid disk type was specified. Must be hyperdisk-balanced or pd-ssd. Zonal in both cases."
  }
}
variable "q_write_cache_iops" {
  description = "OPTIONAL: Specify the iops for hyper-disk.  Range of 3000 to 160000."
  type        = number
  default     = null
  validation {
    condition     = var.q_write_cache_iops == null || can(var.q_write_cache_iops >= 3000 && var.q_write_cache_iops <= 160000)
    error_message = "Hyper disk IOPS must be in the range of 3000 to 160000."
  }
}
variable "term_protection" {
  description = "Enable Termination Protection"
  type        = bool
  default     = true
}
variable "labels" {
  description = "OPTIONAL: Additional global labels"
  type        = map(string)
  default     = null
}

variable "persistent_storage_output" {
  description = "The output of the persistent storage module."
  type = object({
    bucket_names              = list(string)
    bucket_region             = string
    bucket_uris               = list(string)
    deployment_unique_name    = string
    prevent_destroy           = bool
    soft_capacity_limit       = string
    soft_capacity_limit_bytes = string
  })
  nullable = true
  default  = null
}
variable "deploy_provisioner" {
  description = <<EOF
    WARNING: This variable can be set to false in development environment only. Without provisioner deployed,
    node adds, node removes, cluster replace, and bucket additions are not supported in production environments.
    Terraform automation of these operations only works with the provisioner.
    This variable determines whether the provisioner should be deployed."
    EOF
  type        = bool
  default     = true
}
