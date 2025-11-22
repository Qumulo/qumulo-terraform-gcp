# =============================================================================
# BACKEND CONFIGURATION FOR THIS MODULE (Persistent Storage Module)
# =============================================================================
# This backend configuration is for the module itself (when used as root)
# When used as a module, the calling module's backend configuration applies instead
#
# To swap to local backend:
#   Comment out the GCS backend block below - Terraform defaults to local backend when no backend is specified

# -----------------------------------------------------------------------------
# GCS Backend (Default)
# -----------------------------------------------------------------------------
# Comment out this entire block to use local backend instead
terraform {
  backend "gcs" {
    bucket = "my-bucket"
    prefix = "tf-state/persistent-storage"
  }
}
