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

output "bucket_names" {
  description = "Names of the Google buckets created"
  value       = concat(google_storage_bucket.cnq_bucket[*].name)
}
output "bucket_region" {
  description = "Region for GCS buckets"
  value       = local.deployment_region
}
output "bucket_uris" {
  description = "URIs for the buckets created for use with the GCS API"
  value       = local.bucket_uris
}
output "deployment_unique_name" {
  description = "The unique name for this Persistent Storage deployment.  Referenced for the CNQ Cluster deployment."
  value       = local.deployment_unique_name
}
output "prevent_destroy" {
  description = "Prevent the accidental destruction of non-empty buckets with Terraform."
  value       = var.prevent_destroy
}
output "soft_capacity_limit" {
  description = "Soft capacity limit for all buckets combined"
  value       = "${var.soft_capacity_limit} TB"
}
output "soft_capacity_limit_bytes" {
  description = "Soft capacity limit, in bytes, for all buckets combined"
  value       = local.soft_capacity_bytes
}
