#MIT License

#Copyright (c) 2025 Qumulo, Inc.

#Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions =

#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

variable "gcp_project" {
  description = "GCP project"
  type        = string
  nullable    = false
}
variable "gcp_region" {
  description = "GCP region"
  type        = string
  nullable    = false
}
variable "bucket_count_override" {
  description = "The number of buckets to deploy. If unset, the number of buckets is derived from the soft_capacity_limit variable. Requires dev_environment=true."
  type        = number
  nullable    = true
  default     = null
  validation {
    condition     = var.dev_environment || var.bucket_count_override == null
    error_message = "Must set dev_environment=true to use bucket_count_override."
  }
}
variable "deployment_name" {
  description = "Name for this Terraform deployment.  This name plus 11 random alphanumeric characters will be used for all resource names where appropriate."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9a-z\\-]{2,32}$", var.deployment_name))
    error_message = "The deployment_name must be a <=32 characters long and use 0-9 a-z or dash (-)."
  }
}
variable "dev_environment" {
  description = "Disables some checks and restrictions. Leaves the provisioner running after the cluster is deployed. NOT recommended for production"
  type        = bool
  default     = false
}
variable "prevent_destroy" {
  description = "Prevent the accidental destruction of non-empty buckets with Terraform."
  type        = bool
  default     = true
}
variable "soft_capacity_limit" {
  description = "Soft capacity limit for all buckets combined: 50TB to 50000TB (50PB)."
  type        = number
  default     = 500
  validation {
    condition     = var.soft_capacity_limit >= 50 && var.soft_capacity_limit <= 50000
    error_message = "Specify 50TB to 50000TB (50PB) for the soft capacity limit."
  }
}
variable "labels" {
  description = "OPTIONAL: Additional global labels"
  type        = map(string)
  default     = null
}
