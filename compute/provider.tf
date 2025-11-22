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

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
provider "google" {
  alias  = "bucket"
  region = var.gcs_bucket_region
}

# =============================================================================
# REMOTE STATE CONFIGURATION (Persistent Storage State)
# =============================================================================
# This reads the persistent storage state from your persistent-storage deployment
#
# IMPORTANT: Configure the tf_persistent_storage_backend_* variables in terraform.tfvars
# to match your persistent-storage backend configuration.
#
# Set tf_persistent_storage_backend_type = "gcs" for GCS backend (default)
# Set tf_persistent_storage_backend_type = "local" for local backend
#
# For module use: The calling module can pass tf_persistent_storage_backend_*
# variables to configure the backend.

# -----------------------------------------------------------------------------
# GCS Backend for Persistent Storage State
# -----------------------------------------------------------------------------
data "terraform_remote_state" "persistent_storage_gcs" {
  count = var.tf_persistent_storage_backend_type == "gcs" ? 1 : 0

  backend = "gcs"

  config = {
    bucket = var.tf_persistent_storage_backend_bucket
    prefix = var.tf_persistent_storage_backend_prefix
  }

  workspace = var.tf_persistent_storage_workspace
}

# -----------------------------------------------------------------------------
# Local Backend for Persistent Storage State
# -----------------------------------------------------------------------------
data "terraform_remote_state" "persistent_storage_local" {
  count = var.tf_persistent_storage_backend_type == "local" ? 1 : 0

  backend = "local"

  config = {
    path = var.tf_persistent_storage_backend_local_path
  }
}

# Local to select which data source to use
locals {
  persistent_storage_output = var.tf_persistent_storage_backend_type == "gcs" ? data.terraform_remote_state.persistent_storage_gcs[0].outputs : data.terraform_remote_state.persistent_storage_local[0].outputs
}