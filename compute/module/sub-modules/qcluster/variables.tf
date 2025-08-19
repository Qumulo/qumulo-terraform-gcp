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
  validation {
    condition     = var.gce_image_name == null || can(regex("[a-z]([-a-z0-9]*[a-z0-9])", var.gce_image_name))
    error_message = "The GCE image name is invalid."
  }
}
variable "gce_ssh_public_key_path" {
  description = "The local path to a file containing the public key which should be authorized to ssh into the Qumulo nodes"
  type        = string
}
variable "gcp_number_azs" {
  description = "GCP Number of AZs"
  type        = number
}
variable "gcp_project" {
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
variable "gcp_zone_per_node" {
  description = "GCP Zone per GCE instance"
  type        = list(string)
}
variable "gcs_bucket_name" {
  description = "GCS bucket name"
  type        = string
}
variable "functions_gcs_prefix" {
  description = "GCS prefix for shared functions and scripts"
  type        = string
}
variable "boot_dkv_type" {
  description = "EBS type for boot drive and dkv volumes"
  type        = string
}
variable "boot_drive_size" {
  description = "Size of the boot drive for each Qumulo Instance"
  type        = number
}
variable "cluster_floating_ips" {
  description = "The number of floating ips associated with the Qumulo cluster."
  type        = number
}
variable "cluster_fw_ingress_cidrs" {
  description = "GCP firewall ingress source address CIDRs"
  type        = list(string)
}
variable "cluster_name" {
  description = "Qumulo cluster name"
  type        = string
}
variable "cluster_persistent_storage_capacity_limit" {
  description = "Soft capacity limit for all buckets combined."
  type        = string
}
variable "cluster_scripts_path" {
  description = "Local path for Qumulo cluster instance scripts"
  type        = string
}
variable "gcp_cluster_custom_role" {
  description = "OPTIONAL: Fully-qualified custom role name to use for cluster instances (e.g., projects/PROJECT_ID/roles/ROLE_ID). If set, the module will NOT create a custom role and will bind this role instead."
  type        = string
  default     = null
}
variable "debian_package" {
  description = "Debian or RHL package"
  type        = bool
  default     = true
}
variable "deployment_unique_name" {
  description = "Unique Name for this Terraform deployment.  This is the deployment name plus 12 random hex digits that will be used for all resource names where appropriate."
  type        = string
}
variable "existing_deployment_unique_name" {
  description = "The deployment_unique_name of the previous deployed cluster you want to replace"
  type        = string
}
variable "install_qumulo_package" {
  description = <<EOF
  WARNING: Setting install_qumulo_package to false is allowed in development environment only.
  Determine if the script should install qumulo debian or rpm package
  EOF
  type        = bool
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
variable "node_count" {
  description = "Qumulo cluster node count"
  type        = number
}
variable "persistent_bucket_names" {
  description = "Persistent cluster storage bucket names."
  type        = list(string)
}
variable "persistent_storage_deployment_unique_name" {
  description = "The persistent-storage deployment unique name for GCS buckets"
  type        = string
}
variable "qumulo_package_url" {
  description = "A URL accessible to the instances pointing to either the qumulo-core.deb or qumulo-core.rpm for the version of Qumulo you want to install. This may either be a HTTP URL or a gs:// object URL."
  type        = string
  nullable    = false
}
variable "replacement_cluster" {
  description = "OPTIONAL: Build a replacement cluster for an existing Terraform deployment.  This requires a new workspace with a separate state file.  This functionality enables in-service changes to the entire compute & cache front-end."
  type        = bool
}
variable "target_node_count" {
  description = "The desired node count in the cluster.  Used for removing nodes and shrinking the cluster."
  type        = number
}
variable "term_protection" {
  description = "Enable Termination Protection"
  type        = bool
}
variable "write_cache_iops" {
  description = "OPTIONAL: Specify the iops for gp3 or io2"
  type        = number
}
variable "write_cache_tput" {
  description = "OPTIONAL: Specify the throughput, in MB/s, for gp3"
  type        = number
}
variable "write_cache_type" {
  description = "OPTIONAL: Specify the type of EBS flash"
  type        = string
}
variable "labels" {
  description = "Additional global tags"
  type        = map(string)
}
variable "gce_map" {
  description = "This map is used to to set tunables based on the GCE instance type"
  type = map(object({
    wcacheSlots : number
    wcacheSize : number
    wcacheIOPS : number
    wcacheTput : number
    wcacheRefillIOPs : number
    wcacheRefillBps : number
    dkvSlots : number
    dkvSize : number
    rcacheSlots : number
    nodeCap : number
    netTier1 : bool
  }))
  default = {
    "z3-highmem-8-highlssd" = {
      wcacheSlots      = 4
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 662
      netTier1         = false
    }
    "z3-highmem-16-highlssd" = {
      wcacheSlots      = 8
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 1465
      netTier1         = false
    }
    "z3-highmem-22-highlssd" = {
      wcacheSlots      = 16
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 2284
      netTier1         = false
    }
    "z3-highmem-32-highlssd" = {
      wcacheSlots      = 24
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 3650
      netTier1         = false
    }
    "z3-highmem-44-highlssd" = {
      wcacheSlots      = 32
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 5290
      netTier1         = true
    }
    "z3-highmem-14-standardlssd" = {
      wcacheSlots      = 7
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 1191
      netTier1         = false
    }
    "z3-highmem-22-standardlssd" = {
      wcacheSlots      = 16
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 2284
      netTier1         = false
    }
    "z3-highmem-44-highlssd" = {
      wcacheSlots      = 32
      wcacheSize       = 16
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 0
      wcacheRefillBps  = 0
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 0
      nodeCap          = 5290
      netTier1         = true
    }
    "n2-highmem-8" = {
      wcacheSlots      = 3
      wcacheSize       = 50
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 3500
      wcacheRefillBps  = 167
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 4
      nodeCap          = 502
      netTier1         = false
    }
    "n2-highmem-16" = {
      wcacheSlots      = 4
      wcacheSize       = 200
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 7500
      wcacheRefillBps  = 250
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 8
      nodeCap          = 1488
      netTier1         = false
    }
    "n2-highmem-32" = {
      wcacheSlots      = 8
      wcacheSize       = 250
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 8250
      wcacheRefillBps  = 250
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 16
      nodeCap          = 2976
      netTier1         = true
    }
    "n2-highmem-48" = {
      wcacheSlots      = 12
      wcacheSize       = 250
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 8000
      wcacheRefillBps  = 234
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 24
      nodeCap          = 4464
      netTier1         = true
    }
    "n2d-highmem-8" = {
      wcacheSlots      = 3
      wcacheSize       = 50
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 3500
      wcacheRefillBps  = 167
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 4
      nodeCap          = 502
      netTier1         = false
    }
    "n2d-highmem-16" = {
      wcacheSlots      = 4
      wcacheSize       = 200
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 7500
      wcacheRefillBps  = 250
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 8
      nodeCap          = 1488
      netTier1         = false
    }
    "n2d-highmem-32" = {
      wcacheSlots      = 8
      wcacheSize       = 250
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 8250
      wcacheRefillBps  = 250
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 16
      nodeCap          = 2976
      netTier1         = true
    }
    "n2d-highmem-48" = {
      wcacheSlots      = 12
      wcacheSize       = 250
      wcacheIOPS       = 3000
      wcacheTput       = 140
      wcacheRefillIOPs = 8000
      wcacheRefillBps  = 234
      dkvSlots         = 4
      dkvSize          = 4
      rcacheSlots      = 24
      nodeCap          = 4464
      netTier1         = true
    }
  }
}
