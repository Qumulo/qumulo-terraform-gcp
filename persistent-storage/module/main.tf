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

# **** Version 1.1 ****

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

locals {
  #Locked variables post initial deployment
  deployment_project = null_resource.project_lock.triggers.deployment_project
  deployment_region  = null_resource.region_lock.triggers.deployment_region

  #Calculate the number of buckets to create
  number_buckets_calc = ceil(var.soft_capacity_limit / 500)
  number_buckets_min  = local.number_buckets_calc < 16 ? 16 : local.number_buckets_calc
  number_buckets      = var.bucket_count_override != null ? var.bucket_count_override : local.number_buckets_min
  soft_capacity_bytes = tostring(var.soft_capacity_limit * 1000 * 1000 * 1000 * 1000)

  #local variable for cleaner references in subsequent use
  deployment_name_lower  = lower(var.deployment_name)
  deployment_unique_name = null_resource.name_lock.triggers.deployment_unique_name

  #create the list of GCS URIs for the buckets
  bucket_uris = [for i in range(local.number_buckets) : join(",", ["https://storage.googleapis.com/${google_storage_bucket.cnq_bucket[i].name}"])]
}

#Generates 8 digit random alphanumeric for the deployment_unique_name.  Generated on first apply and never changes.
resource "random_string" "deployment" {
  length      = 8
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
#Appends the random alpha numeric to the deployment name.  All resources are tagged/named with this unique name.
resource "null_resource" "name_lock" {
  triggers = {
    deployment_unique_name = "${local.deployment_name_lower}-${random_string.deployment.id}"
  }

  lifecycle { ignore_changes = all }
}

#Generates 11 digit random alphanumeric for each of the bucket names.  Generated on first apply and never changes.
resource "random_string" "bucket" {
  count = local.number_buckets

  length      = 11
  lower       = true
  min_lower   = 8
  min_numeric = 1
  numeric     = true
  special     = false
  upper       = false
  keepers = {
    name = local.deployment_unique_name
  }
  lifecycle { ignore_changes = all }
}

#Create the buckets
resource "google_storage_bucket" "cnq_bucket" {
  count = local.number_buckets

  name                        = "${random_string.bucket[count.index].id}-${local.deployment_unique_name}-qps-${count.index + 1}"
  force_destroy               = !var.prevent_destroy
  location                    = local.deployment_region
  project                     = local.deployment_project
  public_access_prevention    = "enforced"
  storage_class               = "regional"
  uniform_bucket_level_access = true

  labels = merge(var.labels, { name = "${random_string.bucket[count.index].id}-${local.deployment_unique_name}-qps-${count.index + 1}" }, { goog-partner-solution = "solution_urn" })

  hierarchical_namespace {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  dynamic "logging" {
    for_each = var.dev_environment && var.log_bucket != null ? [1]: []
    content {
      log_bucket = var.log_bucket
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore all properties except `force_destroy`
      name,
      location,
      project,
      storage_class,
      uniform_bucket_level_access
    ]
  }
}

#Create the database to store various parameters for the provisioner to leverage
resource "google_firestore_database" "database" {
  project                           = local.deployment_project
  name                              = local.deployment_unique_name
  location_id                       = local.deployment_region
  app_engine_integration_mode       = "DISABLED"
  concurrency_mode                  = "OPTIMISTIC"
  delete_protection_state           = var.prevent_destroy ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"
  deletion_policy                   = "DELETE"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  type                              = "FIRESTORE_NATIVE"
}

resource "google_firestore_document" "bucket-names" {
  project     = local.deployment_project
  collection  = "persistent-storage"
  database    = google_firestore_database.database.name
  document_id = "bucket-names"
  fields = jsonencode({
    bucket-names = {
      stringValue = join(",", flatten(concat(google_storage_bucket.cnq_bucket[*].name)))
    }
  })
}

resource "google_firestore_document" "bucket-uris" {
  project     = local.deployment_project
  collection  = "persistent-storage"
  database    = google_firestore_database.database.name
  document_id = "bucket-uris"
  fields = jsonencode({
    bucket-uris = {
      stringValue = join(",", local.bucket_uris)
    }
  })
}

resource "google_firestore_document" "bucket-region" {
  project     = local.deployment_project
  collection  = "persistent-storage"
  database    = google_firestore_database.database.name
  document_id = "bucket-region"
  fields = jsonencode({
    bucket-region = {
      stringValue = local.deployment_region
    }
  })
}

resource "google_firestore_document" "soft-capacity-limit" {
  project     = local.deployment_project
  collection  = "persistent-storage"
  database    = google_firestore_database.database.name
  document_id = "soft-capacity-limit"
  fields = jsonencode({
    soft-capacity-limit = {
      stringValue = local.soft_capacity_bytes
    }
  })
}
