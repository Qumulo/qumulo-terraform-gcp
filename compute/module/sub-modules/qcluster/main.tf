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

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

data "google_compute_image" "rocky" {
  family  = "rocky-linux-9-optimized-gcp"
  project = "rocky-linux-cloud"
}

data "google_compute_subnetwork" "selected" {
  name    = var.gcp_subnet_name
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "google_compute_address" "floating" {
  count        = var.cluster_floating_ips
  subnetwork   = data.google_compute_subnetwork.selected.id
  name         = "${var.deployment_unique_name}-floating-ip-${count.index}"
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_firestore_document" "new-cluster" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.persistent_storage_deployment_unique_name
  document_id = "new-cluster"
  fields = jsonencode({
    new-cluster = {
      stringValue = "true"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

data "external" "fs-token" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_token_ps1}",
    var.gcp_project_id,
    var.persistent_storage_deployment_unique_name,
    var.deployment_unique_name
    ] : [
    "bash", "${local.fs_get_token_sh}", var.gcp_project_id, var.persistent_storage_deployment_unique_name, var.deployment_unique_name
  ]
}

data "external" "new-cluster" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_ps1}",
    "new-cluster",
    var.gcp_project_id,
    var.persistent_storage_deployment_unique_name,
    var.deployment_unique_name,
    local.token,
    "false"
    ] : [
    "bash", "${local.fs_get_sh}", "new-cluster", var.gcp_project_id, var.persistent_storage_deployment_unique_name, var.deployment_unique_name, local.token, "false"
  ]

  depends_on = [google_firestore_document.new-cluster]
}

data "external" "instance-ids" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_ps1}",
    "instance-ids",
    var.gcp_project_id,
    var.persistent_storage_deployment_unique_name,
    var.deployment_unique_name,
    local.token,
    local.new_cluster ? "true" : "false"
    ] : [
    "bash", "${local.fs_get_sh}", "instance-ids", var.gcp_project_id, var.persistent_storage_deployment_unique_name, var.deployment_unique_name, local.token, local.new_cluster
  ]

  depends_on = [google_firestore_document.new-cluster]
}

data "external" "floating-ip-count" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_ps1}",
    "floating-ip-count",
    var.gcp_project_id,
    var.persistent_storage_deployment_unique_name,
    var.deployment_unique_name,
    local.token,
    local.new_cluster ? "true" : "false"
    ] : [
    "bash", "${local.fs_get_sh}", "floating-ip-count", var.gcp_project_id, var.persistent_storage_deployment_unique_name, var.deployment_unique_name, local.token, local.new_cluster
  ]

  depends_on = [google_firestore_document.new-cluster]
}

locals {
  #Convert dashes to underscores because role ids in GCP won't accept dashes
  deployment_unique_name_underscore = replace(var.deployment_unique_name, "-", "_")

  # Check the type of shell being used for subsequent curl commands to access Firestore
  is_windows       = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  fs_get_token_sh  = "${var.cluster_scripts_path}fs_get_token.sh"
  fs_get_token_ps1 = "${var.cluster_scripts_path}fs_get_token.ps1"
  fs_get_sh        = "${var.cluster_scripts_path}fs_get.sh"
  fs_get_ps1       = "${var.cluster_scripts_path}fs_get.ps1"
  token            = data.external.fs-token.result["value"]

  # Check to make sure cluster reduction in node count is valid
  new_cluster                = data.external.new-cluster.result["value"] == "true" ? true : false
  existing_node_count        = local.new_cluster ? 0 : length(tolist(split(",", data.external.instance-ids.result["value"])))
  check_cluster_remove_nodes = local.new_cluster ? false : (local.existing_node_count > var.node_count ? true : false)

  # Check to make sure a new TF workspace is being used (ie new state) for a replacement cluster
  check_workspace_on_replace = var.replacement_cluster && var.existing_deployment_unique_name == var.deployment_unique_name ? true : false

  # Check to make sure the FIPS count is not reducing the number of floating IPs
  existing_floating_ips_count = local.new_cluster ? 0 : (data.external.floating-ip-count.result["value"] == "null" || data.external.floating-ip-count.result["value"] == "" ? 0 : data.external.floating-ip-count.result["value"])
  check_floating_ips_count    = local.new_cluster ? false : (var.cluster_floating_ips < local.existing_floating_ips_count ? true : false)

  # Check the instance type to make sure it is large enough for the soft capacity limit
  capacity_limit_tb           = var.cluster_persistent_storage_capacity_limit / 1000 / 1000 / 1000 / 1000
  capacity_per_node_needed    = var.target_node_count == null || var.replacement_cluster ? local.capacity_limit_tb / var.node_count : local.capacity_limit_tb / var.target_node_count
  capacity_per_node_available = lookup(var.gce_map[var.instance_type], "nodeCap")
  capacity_unconstrained      = local.capacity_per_node_needed <= local.capacity_per_node_available ? true : false

  # Check to enable Tier_1 bandwidth support for GCE
  network_performance = lookup(var.gce_map[var.instance_type], "netTier1")

  # Deb or RHL image
  gce_image = var.debian_package ? data.google_compute_image.ubuntu.self_link : data.google_compute_image.rocky.self_link

  # Use bootstrap script that ensures Python is available before running user-data.py
  user_data_template = "${var.cluster_scripts_path}bootstrap-python.sh"

  # Handle the CMK key name for the boot disk
  boot_disk = var.kms_key_name != null ? [{ kms_key_self_link = var.kms_key_name }] : [{}]

  device_names = [
    "disk-1",
    "disk-2",
    "disk-3",
    "disk-4",
    "disk-5",
    "disk-6",
    "disk-7",
    "disk-8",
    "disk-9",
    "disk-10",
    "disk-11",
    "disk-12",
    "disk-13",
    "disk-14",
    "disk-15",
    "disk-16",
    "disk-17",
    "disk-18",
    "disk-19",
    "disk-20",
    "disk-21",
    "disk-22",
    "disk-23",
    "disk-24",
    "disk-25",
    "disk-26",
    "disk-27",
    "disk-28",
    "disk-29",
    "disk-30",
    "disk-31",
    "disk-32",
    "disk-33",
    "disk-34",
    "disk-35",
    "disk-36",
    "disk-37",
    "disk-38",
    "disk-39",
    "disk-40",
    "disk-41",
    "disk-42",
    "disk-43",
    "disk-44",
    "disk-45",
    "disk-46",
    "disk-47",
    "disk-48",
    "disk-49",
    "disk-50",
    "disk-51",
    "disk-52",
    "disk-53",
    "disk-54",
    "disk-55",
    "disk-56",
    "disk-57",
    "disk-58",
    "disk-59",
    "disk-60",
    "disk-61",
    "disk-62",
    "disk-63",
    "disk-64",
    "disk-65",
    "disk-66",
    "disk-67",
    "disk-68",
    "disk-69",
    "disk-70",
    "disk-71",
    "disk-72",
    "disk-73",
    "disk-74",
    "disk-75",
    "disk-76",
    "disk-77",
    "disk-78",
    "disk-79",
    "disk-80",
    "disk-81",
    "disk-82",
    "disk-83",
    "disk-84",
    "disk-85",
    "disk-86",
    "disk-87",
    "disk-88",
    "disk-89",
    "disk-90",
    "disk-91",
    "disk-92",
    "disk-93",
    "disk-94",
    "disk-95",
    "disk-96",
    "disk-97",
    "disk-98",
    "disk-99",
    "disk-100",
    "disk-101",
    "disk-102",
    "disk-103",
    "disk-104",
    "disk-105",
    "disk-106",
    "disk-107",
    "disk-108",
    "disk-109",
    "disk-110",
    "disk-111",
    "disk-112",
    "disk-113",
    "disk-114",
    "disk-115",
    "disk-116",
    "disk-117",
    "disk-118",
    "disk-119",
    "disk-120"
  ]

  # Write cache tput/iops
  write_cache_tput_lt25 = var.write_cache_tput == null ? lookup(var.gce_map[var.instance_type], "wcacheTput_lt25") : var.write_cache_tput
  write_cache_iops_lt25 = var.write_cache_iops == null ? lookup(var.gce_map[var.instance_type], "wcacheIOPS_lt25") : var.write_cache_iops
  write_cache_tput_gt24 = var.write_cache_tput == null ? lookup(var.gce_map[var.instance_type], "wcacheTput_gt24") : var.write_cache_tput
  write_cache_iops_gt24 = var.write_cache_iops == null ? lookup(var.gce_map[var.instance_type], "wcacheIOPS_gt24") : var.write_cache_iops
  write_cache_tput      = var.node_count < 25 ? local.write_cache_tput_lt25 : local.write_cache_tput_gt24
  write_cache_iops      = var.node_count < 25 ? local.write_cache_iops_lt25 : local.write_cache_iops_gt24

  # Cluster tunables
  refill_IOPS = startswith(var.instance_type, "n2-") ? lookup(var.gce_map[var.instance_type], "wcacheRefillIOPs") : local.write_cache_iops
  refill_Bps  = startswith(var.instance_type, "n2-") ? lookup(var.gce_map[var.instance_type], "wcacheRefillBps") : local.write_cache_tput
  disk_count  = lookup(var.gce_map[var.instance_type], "wcacheSlots")

  # Read Cache disks
  read_disk_count  = lookup(var.gce_map[var.instance_type], "rcacheSlots")
  dkv_disk_count   = lookup(var.gce_map[var.instance_type], "dkvSlots")
  write_disk_count = lookup(var.gce_map[var.instance_type], "wcacheSlots")
  total_disk_count = local.read_disk_count + local.write_disk_count + local.dkv_disk_count + 1

  #DKV Persistent Disk volumes
  dkv_pd_block_devices = [
    for i in range(local.dkv_disk_count) : {
      device_name  = local.device_names[i]
      volume_type  = var.boot_dkv_type
      volume_size  = lookup(var.gce_map[var.instance_type], "dkvSize")
      volume_tput  = 140
      volume_iops  = 2000
      volume_label = "dkv"
    }
  ]

  #Write Cache Persistent Disk volumes
  wcache_pd_block_devices = [
    for i in range(local.write_disk_count) : {
      device_name  = local.device_names[i + local.dkv_disk_count]
      volume_type  = var.write_cache_type
      volume_size  = lookup(var.gce_map[var.instance_type], "wcacheSize")
      volume_tput  = local.write_cache_tput
      volume_iops  = local.write_cache_iops
      volume_label = "wrt"
    }
  ]

  pd_block_devices = concat(
    local.wcache_pd_block_devices,
    local.dkv_pd_block_devices
  )

  ingress_rules = [
    {
      port        = 21
      description = "TCP ports for FTP"
      protocol    = "tcp"
    },
    {
      port        = 22
      description = "TCP ports for SSH"
      protocol    = "tcp"
    },
    {
      port        = 80
      description = "TCP ports for HTTP"
      protocol    = "tcp"
    },
    {
      port        = 111
      description = "TCP ports for SUNRPC"
      protocol    = "tcp"
    },
    {
      port        = 443
      description = "TCP ports for HTTPS"
      protocol    = "tcp"
    },
    {
      port        = 445
      description = "TCP ports for SMB"
      protocol    = "tcp"
    },
    {
      port        = 2049
      description = "TCP ports for NFS"
      protocol    = "tcp"
    },
    {
      port        = 3712
      description = "TCP ports for Replication"
      protocol    = "tcp"
    },
    {
      port        = 3713
      description = "TCP ports for CDF"
      protocol    = "tcp"
    },
    {
      port        = 5201
      description = "TCP ports for IPERF3"
      protocol    = "tcp"
    },    
    {
      port        = 8000
      description = "TCP ports for REST"
      protocol    = "tcp"
    },
    {
      port        = 111
      description = "UDP port for SUNRPC"
      protocol    = "udp"
    },
    {
      port        = 9000
      description = "TCP port for S3"
      protocol    = "tcp"
    },
    {
      port        = 2049
      description = "UDP port for NFS"
      protocol    = "udp"
    },
    {
      port        = 5201
      description = "UDP ports for IPERF3"
      protocol    = "udp"
    }    
  ]
}
# Check the capacity constraint and throw an error if a larger instance type is required
resource "null_resource" "check_capacity_constraint" {
  count = local.capacity_unconstrained ? 0 : "The number of and type of instances chosen will not support the soft_capacity_limit requested.  Increase the node count or switch to a larger instance type."
}

resource "google_compute_firewall" "egress" {
  name     = "${var.deployment_unique_name}-qumulo-egress"
  network  = var.gcp_vpc_name
  priority = 700
  project  = var.gcp_project_id

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  direction          = "EGRESS"

  target_tags = ["${var.deployment_unique_name}-cluster"]
}

resource "google_compute_firewall" "ingress" {
  name     = "${var.deployment_unique_name}-qumulo-ingress"
  network  = var.gcp_vpc_name
  priority = 700
  project  = var.gcp_project_id

  dynamic "allow" {
    for_each = local.ingress_rules
    content {
      protocol = allow.value.protocol
      ports    = [allow.value.port]
    }
  }

  source_ranges = var.cluster_fw_ingress_cidrs
  direction     = "INGRESS"

  target_tags = ["${var.deployment_unique_name}-cluster"]
}

resource "google_compute_firewall" "internal" {
  name     = "${var.deployment_unique_name}-qumulo-internal"
  network  = var.gcp_vpc_name
  priority = 700
  project  = var.gcp_project_id

  allow {
    protocol = "all"
  }

  source_tags = ["${var.deployment_unique_name}-cluster"]
  target_tags = ["${var.deployment_unique_name}-cluster"]
  direction   = "INGRESS"
}

resource "google_service_account" "q_access" {
  account_id   = "${var.deployment_unique_name}-cpt"
  display_name = "Qumulo Cluster Service Account"
  project      = var.gcp_project_id
}

resource "google_project_iam_custom_role" "cluster_role" {
  count       = var.gcp_cluster_custom_role == null ? 1 : 0
  role_id     = "${local.deployment_unique_name_underscore}_cluster_role"
  title       = "Qumulo GCE Role for Cluster ${var.deployment_unique_name}"
  description = "Permissions for compute instances in the cluster"
  project     = var.gcp_project_id
  permissions = [
    "logging.logEntries.create",
    "compute.instances.get",
    "compute.instances.list",
    "compute.instances.updateNetworkInterface",
    "compute.regions.get"
  ]
}

resource "google_project_iam_member" "cluster_role_binding" {
  project = var.gcp_project_id
  role    = var.gcp_cluster_custom_role == null ? google_project_iam_custom_role.cluster_role[0].id : var.gcp_cluster_custom_role
  member  = "serviceAccount:${google_service_account.q_access.email}"
}

resource "google_kms_crypto_key_iam_member" "cmk_binding1" {
  count = var.kms_key_name == null ? 0 : 1

  crypto_key_id = var.kms_key_name
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.q_access.email}"
}

resource "google_kms_crypto_key_iam_member" "cmk_binding2" {
  count = var.kms_key_name == null ? 0 : 1

  crypto_key_id = var.kms_key_name
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.gcp_project_number}@compute-system.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "bucket_role_binding" {
  count = length(var.persistent_bucket_names)

  bucket = var.persistent_bucket_names[count.index]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.q_access.email}"
}

resource "google_storage_bucket_iam_member" "utility_bucket_role_binding" {
  bucket = var.gcs_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.q_access.email}"
}

resource "google_compute_resource_policy" "placement_policy" {
  count = var.gcp_number_azs == 1 && !startswith(var.instance_type, "z3-") ? 1 : 0

  name    = var.deployment_unique_name
  project = var.gcp_project_id
  region  = var.gcp_region
  group_placement_policy {
    collocation = "COLLOCATED"
  }
}

resource "google_compute_instance" "node" {
  count = var.node_count

  deletion_protection = var.term_protection
  machine_type        = var.instance_type
  name                = "${var.deployment_unique_name}-node-${count.index + 1}"
  project             = var.gcp_project_id
  resource_policies   = var.gcp_number_azs == 1 && !startswith(var.instance_type, "z3-") ? [google_compute_resource_policy.placement_policy[0].self_link] : []
  tags                = ["${var.deployment_unique_name}-cluster"]
  zone                = var.gcp_zone_per_node[count.index]

  metadata_startup_script = templatefile("${local.user_data_template}", {
    total_disk_count       = local.total_disk_count
    qumulo_package_url     = var.qumulo_package_url
    install_qumulo_package = var.install_qumulo_package ? "true" : "false"
    gcs_bucket_name        = var.gcs_bucket_name
    functions_gcs_prefix   = var.functions_gcs_prefix
  })

  labels = merge(var.labels, { name = "${var.deployment_unique_name}-node-${count.index + 1}" }, { goog-partner-solution = "solution_urn" })

  boot_disk {
    initialize_params {
      image  = var.gce_image_name == null ? local.gce_image : var.gce_image_name
      size   = var.boot_drive_size
      type   = var.boot_dkv_type
      labels = merge(var.labels, { name = "${var.deployment_unique_name}-node-${count.index + 1}-boot-disk" }, { goog-partner-solution = "solution_urn" })
    }

    kms_key_self_link = try(local.boot_disk[0].kms_key_self_link, null)
    guest_os_features = ["MULTI_IP_SUBNET"]
  }

  dynamic "scratch_disk" {
    for_each = range(local.read_disk_count)
    content {
      interface = "NVME"
    }
  }

  network_interface {
    network            = var.gcp_vpc_name
    subnetwork         = var.gcp_subnet_name
    subnetwork_project = var.gcp_project_id
  }

  network_performance_config {
    total_egress_bandwidth_tier = local.network_performance ? "TIER_1" : "DEFAULT"
  }

  scheduling {
    on_host_maintenance = "MIGRATE"
    automatic_restart   = true
  }

  service_account {
    email  = google_service_account.q_access.email
    scopes = ["cloud-platform"]
  }

  metadata = var.gce_ssh_public_key_path == null ? {} : {
    "ssh-keys" = format("ubuntu:%s", file(var.gce_ssh_public_key_path))
  }

  lifecycle {
    ignore_changes = [attached_disk, boot_disk, machine_type, metadata_startup_script, name, network_interface, scratch_disk, zone]

    precondition {
      condition     = local.check_cluster_remove_nodes == false
      error_message = "q_node_count is less than the number of nodes in the cluster.  Execute a Terraform apply with q_target_node_count to reduce the cluster size OR enter the correct cluster size for q_node_count."
    }

    precondition {
      condition     = local.check_floating_ips_count == false
      error_message = "The number of floating IPs in the cluster can't be reduced. Use a larger value for q_cluster_floating_ips."
    }

    precondition {
      condition     = local.check_workspace_on_replace == false
      error_message = "A Cluster Replace requires a new Terraform workspace (ie new state file).  Create a new TF workspace, then execute the cluster replace."
    }
  }
}

module "disks" {
  source = "../qcluster-disks"

  count = var.node_count

  devices      = local.pd_block_devices
  kms_key_name = var.kms_key_name
  node = {
    id   = google_compute_instance.node[count.index].id
    name = "${var.deployment_unique_name}-node-${count.index + 1}"
    zone = google_compute_instance.node[count.index].zone
  }
  gcp_project_id = var.gcp_project_id

  labels = var.labels
}
