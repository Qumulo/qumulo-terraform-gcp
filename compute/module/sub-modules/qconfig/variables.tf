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

variable "gcp_region" {
  description = "GCP region"
  type        = string
}
variable "gcp_subnet_cidr" {
  description = "GCP subnet CIDR"
  type        = string
}
variable "gcp_zones" {
  description = "GCP zones"
  type        = list(string)
}
variable "node_count" {
  description = "Qumulo cluster node count"
  type        = number
}
variable "persistent_storage_bucket_region" {
  description = "GCP region for the GCS buckets and Qumulo persistent storage"
  type        = string
  nullable    = false
}
variable "replacement_cluster" {
  description = "OPTIONAL: Build a replacment cluster for an existing Terraform deployment.  This requires a new workspace with a separate state file.  This functionality enables in-service changes to the entire compute & cache front-end."
  type        = bool
}
variable "target_node_count" {
  description = "The desired node count in the cluster.  Used for removing nodes and shrinking the cluster."
  type        = number
}
