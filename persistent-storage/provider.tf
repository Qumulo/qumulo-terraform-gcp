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

# Comment out this block if you want to use a local backend
# Below is an example for storing state on GCS for this Terraform deployment.
# You cannot put variables in the backend resource below.
# Whatever you choose to do, the compute/provider.tf and this persistent-storage/provider.tf must point to the correct bucket/path where you are storing state.
# State for the two modules MUST be separate.  You need only specify a bucket below.
terraform {
  backend "gcs" {
    bucket = "my-bucket"
    prefix = "tf-state/persistent-storage"
  }
}
