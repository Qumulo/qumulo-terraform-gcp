# MIT License
#
# Copyright (c) 2025 Qumulo, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions =
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


resource "google_compute_disk" "persistent_disk" {
  count = length(var.devices)

  name    = "${var.node.name}-${var.devices[count.index].volume_label}-${var.devices[count.index].device_name}"
  size    = var.devices[count.index].volume_size
  type    = var.devices[count.index].volume_type
  zone    = var.node.zone
  labels  = merge(var.labels, { name = "${var.node.name}-${var.devices[count.index].volume_label}-${var.devices[count.index].device_name}" })
  project = var.gcp_project

  provisioned_throughput = var.devices[count.index].volume_type == "pd-ssd" || var.devices[count.index].volume_type == "pd-balanced" ? null : var.devices[count.index].volume_tput
  provisioned_iops       = var.devices[count.index].volume_type == "pd-ssd" || var.devices[count.index].volume_type == "pd-balanced" ? null : var.devices[count.index].volume_iops


  dynamic "disk_encryption_key" {
    for_each = var.kms_key_name != null ? [1] : []
    content {
      kms_key_self_link = var.kms_key_name
    }
  }

  lifecycle {
    ignore_changes = [disk_encryption_key, labels, name, size, type, zone]
  }
}

resource "google_compute_attached_disk" "persistent_disk" {
  count = length(var.devices)

  disk     = google_compute_disk.persistent_disk[count.index].id
  instance = var.node.id
  project  = var.gcp_project
}

