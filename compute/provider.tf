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
  project = var.gcp_project
  region  = var.gcp_region
}
provider "google" {
  alias  = "bucket"
  region = var.gcs_bucket_region
}

# Comment out this block if you want to use a local backend
# Below is an example for storing state on GCS for this Terraform deployment.
# You cannot put variables in the backend resource below.
# Whatever you choose to do, the persistent-storage/provider.tf and this compute/provider.tf must point to the correct bucket/path where you are storing state.
# State for the two modules MUST be separate.  You need only specify a bucket below.
terraform {
  backend "gcs" {
    bucket = "my-bucket"
    prefix = "tf-state/compute"
  }
}

#Comment out this block if you are using a local backend
#You MUST specify the same bucket below as you specified for the backend above.
#You MUST specify the same prefix as configured in the persistent-storage/provider.tf
data "terraform_remote_state" "persistent_storage" {
  backend = "gcs"

  config = {
    bucket = "my-bucket"
    prefix = "tf-state/persistent-storage"
  }

  workspace = var.tf_persistent_storage_workspace
}

#Uncomment this block if you are using a local backend
#If you are storing state locally - not recommended for production - here's an example of how to setup the data source for persistent-storage
#data "terraform_remote_state" "persistent_storage" {
#  backend = "local"
#
#  config = {
#    path = "./persistent-storage/terraform.tfstate"
#  }
#}
#