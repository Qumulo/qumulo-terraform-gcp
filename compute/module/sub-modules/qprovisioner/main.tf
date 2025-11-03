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

data "google_compute_image" "ubuntu-provisioner" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

locals {
  #Convert dashes to underscores because role ids in GCP won't accept dashes
  deployment_unique_name_underscore = replace(var.deployment_unique_name, "-", "_")

  # GCE image name
  gce_image = data.google_compute_image.ubuntu-provisioner.self_link

  ingress_rules = [
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
      port        = 443
      description = "TCP ports for HTTPS"
      protocol    = "tcp"
    }
  ]

  # Handle the CMK key name for the boot disk
  boot_disk = var.kms_key_name != null ? [{ kms_key_self_link = var.kms_key_name }] : [{}]

}

resource "google_compute_firewall" "egress" {
  name     = "${var.deployment_unique_name}-qumulo-provisioner-egress"
  network  = var.gcp_vpc_name
  priority = 700
  project  = var.gcp_project_id

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  direction          = "EGRESS"

  target_tags = ["${var.deployment_unique_name}-provisioner"]
}

resource "google_compute_firewall" "ingress" {
  name     = "${var.deployment_unique_name}-qumulo-provisioner-ingress"
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

  target_tags = ["${var.deployment_unique_name}-provisioner"]
}

resource "google_firestore_document" "creation-number-azs" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "creation-number-azs"
  fields = jsonencode({
    creation-number-azs = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "creation-version" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "creation-version"
  fields = jsonencode({
    creation-version = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "installed-version" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "installed-version"
  fields = jsonencode({
    installed-version = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "cluster-type" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "cluster-type"
  fields = jsonencode({
    cluster-type = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "cluster-secrets-name" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "cluster-secrets-name"
  fields = jsonencode({
    cluster-secrets-name = {
      stringValue = var.cluster_secrets_name
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "bucket-uris" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "bucket-uris"
  fields = jsonencode({
    bucket-uris = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "bucket-names" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "bucket-names"
  fields = jsonencode({
    bucket-names = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "soft-capacity-limit" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "soft-capacity-limit"
  fields = jsonencode({
    soft-capacity-limit = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "tunables" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "tunables"
  fields = jsonencode({
    tunables = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "fault-domain-ids" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "fault-domain-ids"
  fields = jsonencode({
    fault-domain-ids = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "instance-ids" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "instance-ids"
  fields = jsonencode({
    instance-ids = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "node-ips" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "node-ips"
  fields = jsonencode({
    node-ips = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "float-ips" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "float-ips"
  fields = jsonencode({
    float-ips = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "uuid" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "uuid"
  fields = jsonencode({
    uuid = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "last-run-status" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "last-run-status"
  fields = jsonencode({
    last-run-status = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_firestore_document" "floating-ip-count" {
  project     = var.gcp_project_id
  collection  = var.deployment_unique_name
  database    = var.cluster_persistent_storage_deployment_unique_name
  document_id = "floating-ip-count"
  fields = jsonencode({
    floating-ip-count = {
      stringValue = "null"
    }
  })
  lifecycle { ignore_changes = [fields] }
}

resource "google_service_account" "q_access" {
  account_id   = "${var.deployment_unique_name}-pvn"
  display_name = "Qumulo Provisioner Service Account"
  project      = var.gcp_project_id
}

resource "google_project_iam_custom_role" "provisioner_role" {
  count       = var.gcp_provisioner_custom_role == null ? 1 : 0
  role_id     = "${local.deployment_unique_name_underscore}_provisioner_role"
  title       = "Qumulo GCE Role for Provisioner ${var.deployment_unique_name}"
  description = "Permissions for the provisioner compute instance"
  project     = var.gcp_project_id
  permissions = [
    "compute.disks.get",
    "compute.disks.setLabels",
    "compute.disks.update",
    "compute.firewalls.get",
    "compute.firewalls.update",
    "compute.instances.get",
    "compute.instances.list",
    "compute.instances.setMetadata",
    "compute.instances.setLabels",
    "compute.instances.update",
    "compute.networks.updatePolicy",
    "compute.zoneOperations.get",
    "datastore.entities.create",
    "datastore.entities.get",
    "datastore.entities.list",
    "datastore.entities.update",
    "secretmanager.versions.access",
    "secretmanager.versions.add"
  ]
}

resource "google_project_iam_member" "provisioner_role_binding" {
  project = var.gcp_project_id
  role    = var.gcp_provisioner_custom_role == null ? google_project_iam_custom_role.provisioner_role[0].id : var.gcp_provisioner_custom_role
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
  count = length(var.cluster_persistent_bucket_names)

  bucket = var.cluster_persistent_bucket_names[count.index]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.q_access.email}"
}

resource "google_storage_bucket_iam_member" "utility_bucket_role_binding" {
  bucket = var.gcs_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.q_access.email}"
}

resource "google_compute_instance" "provisioner" {
  machine_type = var.instance_type
  name         = "${var.deployment_unique_name}-provisioner"
  project      = var.gcp_project_id
  tags         = ["${var.deployment_unique_name}-provisioner"]
  zone         = var.gcp_zone

  metadata_startup_script = templatefile("${var.scripts_path}provision.py", {
    bucket_name                               = var.gcs_bucket_name
    cluster_name                              = var.cluster_name
    cluster_persistent_bucket_names           = join(",", var.cluster_persistent_bucket_names)
    cluster_persistent_bucket_uris            = join(",", var.cluster_persistent_bucket_uris)
    cluster_persistent_storage_capacity_limit = var.cluster_persistent_storage_capacity_limit
    cluster_persistent_storage_type           = var.cluster_persistent_storage_type
    cluster_secrets_name                      = var.cluster_secrets_name
    deployment_unique_name                    = var.deployment_unique_name
    existing_deployment_unique_name           = var.existing_deployment_unique_name == null ? "" : var.existing_deployment_unique_name
    fault_domain_ids                          = join(",", var.cluster_fault_domain_ids)
    flash_tput                                = var.flash_tput
    flash_iops                                = var.flash_iops
    floating_ips                              = join(",", local.all_floating_ips)
    functions_gcs_prefix                      = var.functions_gcs_prefix
    install_gcs_prefix                        = var.install_gcs_prefix
    instance_ids                              = join(",", var.cluster_instance_ids)
    max_floating_ips                          = 14
    node1_ip                                  = var.cluster_node1_ip
    number_azs                                = tostring(var.gcp_number_azs)
    qumulo_package_url                        = var.qumulo_package_url
    persistent_storage_deployment_unique_name = var.cluster_persistent_storage_deployment_unique_name
    primary_ips                               = join(",", var.cluster_primary_ips)
    project                                   = var.gcp_project_id
    region                                    = var.gcp_region
    replacement_cluster                       = var.replacement_cluster
    subnet_cidr                               = var.subnet_cidr
    target_node_count                         = var.target_node_count
    temporary_password                        = var.cluster_temporary_password
    tun_refill_IOPS                           = var.tun_refill_IOPS
    tun_refill_Bps                            = var.tun_refill_Bps
    tun_disk_count                            = var.tun_disk_count
    zone                                      = var.gcp_zone
    dev_environment                           = var.dev_environment
  })

  labels = merge(var.labels, { name = "${var.deployment_unique_name}-provisioner" }, { goog-partner-solution = "isol_plb32_0014m00001h36ntqay_f5vsyrhwimcgjy5wgrnbmghhviuu7czp" })

  boot_disk {
    initialize_params {
      image  = local.gce_image
      size   = 40
      type   = var.boot_type
      labels = merge(var.labels, { name = "${var.deployment_unique_name}-provisioner-boot-disk" }, { goog-partner-solution = "isol_plb32_0014m00001h36ntqay_f5vsyrhwimcgjy5wgrnbmghhviuu7czp" })
    }

    kms_key_self_link = try(local.boot_disk[0].kms_key_self_link, null)
  }

  network_interface {
    network            = var.gcp_vpc_name
    subnetwork         = var.gcp_subnet_name
    subnetwork_project = var.gcp_project_id
  }

  scheduling {
    on_host_maintenance = "MIGRATE"
    automatic_restart   = true
  }

  service_account {
    email  = google_service_account.q_access.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    ignore_changes = [boot_disk, network_interface]
  }
}

#This resource monitors the status of the qprovisioner module (GCE Instance) that executes secondary provisioning of the Qumulo cluster.
#It pulls status from FireStore where the provisioner writest status/state.

locals {
  is_windows  = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  status_sh   = "${var.scripts_path}status.sh"
  status_ps1  = "${var.scripts_path}status.ps1"
  status_vars = { project = var.gcp_project_id, database = var.cluster_persistent_storage_deployment_unique_name, collection = var.deployment_unique_name, gce_instance_name = google_compute_instance.provisioner.name, token = local.token }

  fs_get_token_sh   = "${var.scripts_path}fs_get_token.sh"
  fs_get_token_ps1  = "${var.scripts_path}fs_get_token.ps1"
  fs_get_sh         = "${var.scripts_path}fs_get.sh"
  fs_get_ps1        = "${var.scripts_path}fs_get.ps1"
  fs_get_status_sh  = "${var.scripts_path}fs_get_status.sh"
  fs_get_status_ps1 = "${var.scripts_path}fs_get_status.ps1"
  token             = data.external.fs-token.result["value"]

  floating_ips_deployment_unique_name = var.existing_deployment_unique_name != null && var.replacement_cluster ? var.existing_deployment_unique_name : var.deployment_unique_name
  existing_floating_ips_result        = data.external.existing-floating-ips.result["value"]
  existing_floating_ips               = local.existing_floating_ips_result != "null" ? tolist(split(",", local.existing_floating_ips_result)) : []
  all_floating_ips                    = tolist(setunion(local.existing_floating_ips, var.cluster_floating_ips))
}

data "external" "fs-token" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_token_ps1}",
    var.gcp_project_id,
    var.cluster_persistent_storage_deployment_unique_name,
    var.deployment_unique_name
    ] : [
    "bash", "${local.fs_get_token_sh}", var.gcp_project_id, var.cluster_persistent_storage_deployment_unique_name, var.deployment_unique_name
  ]

  depends_on = [google_firestore_document.last-run-status]
}

data "external" "provisioner" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_status_ps1}",
    "last-run-status",
    var.gcp_project_id,
    var.cluster_persistent_storage_deployment_unique_name,
    var.deployment_unique_name,
    local.token,
    "false"
    ] : [
    "bash", "${local.fs_get_status_sh}", "last-run-status", var.gcp_project_id, var.cluster_persistent_storage_deployment_unique_name, var.deployment_unique_name, local.token, "false"
  ]

  depends_on = [null_resource.provisioner_status]
}

data "external" "existing-floating-ips" {
  program = local.is_windows ? [
    "powershell", "-ExecutionPolicy", "Bypass", "-File", "${local.fs_get_ps1}",
    "float-ips",
    var.gcp_project_id,
    var.cluster_persistent_storage_deployment_unique_name,
    local.floating_ips_deployment_unique_name,
    local.token,
    "false"
    ] : [
    "bash", "${local.fs_get_sh}", "float-ips", var.gcp_project_id, var.cluster_persistent_storage_deployment_unique_name, local.floating_ips_deployment_unique_name, local.token, "false"
  ]

  depends_on = [google_firestore_document.float-ips]
}

resource "null_resource" "provisioner_status" {
  count = var.check_provisioner_shutdown ? 1 : 0

  provisioner "local-exec" {
    quiet       = true
    interpreter = local.is_windows ? ["PowerShell", "-Command"] : []
    command     = local.is_windows ? templatefile(local.status_ps1, local.status_vars) : templatefile(local.status_sh, local.status_vars)
  }

  triggers = {
    script_hash = "${sha256("${google_compute_instance.provisioner.metadata_startup_script}")}"
  }

  depends_on = [google_compute_instance.provisioner, google_firestore_document.last-run-status]
}
