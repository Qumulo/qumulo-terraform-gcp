<!-- BEGIN_TF_DOCS -->

<a target="_blank" href="https://qumulo.com/"><img src="./.config/images/qumulo-scale-anywhere-logo.webp" style="width:150px;height:53px;"></a>

## Terraform Documentation

> ℹ️ **Note:** This repository uses documentation generated with Terraform-Docs.  

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.48.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_check_provisioner_shutdown"></a> [check\_provisioner\_shutdown](#input\_check\_provisioner\_shutdown) | Executes a local-exec script on the Terraform machine to check if the provisioner instance shutdown which indicates a successful cluster deployment. | `bool` | `true` | no |
| <a name="input_deploy_provisioner"></a> [deploy\_provisioner](#input\_deploy\_provisioner) | WARNING: This variable can be set to false in development environment only. Without provisioner deployed,<br/>    node adds, node removes, cluster replace, and bucket additions are not supported in production environments.<br/>    Terraform automation of these operations only works with the provisioner.<br/>    This variable determines whether the provisioner should be deployed." | `bool` | `true` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name for this Terraform deployment.  This name plus 7 random alphanumeric digits will be used for all resource names where appropriate. | `string` | n/a | yes |
| <a name="input_dev_environment"></a> [dev\_environment](#input\_dev\_environment) | Disables some checks and restrictions. Leaves the provisioner running after the cluster is deployed. NOT recommended for production | `bool` | `false` | no |
| <a name="input_gce_image_name"></a> [gce\_image\_name](#input\_gce\_image\_name) | GCE Image Name | `string` | n/a | yes |
| <a name="input_gce_ssh_public_key_path"></a> [gce\_ssh\_public\_key\_path](#input\_gce\_ssh\_public\_key\_path) | OPTIONAL: The local path to a file containing the public key which should be authorized to ssh into the Qumulo nodes | `string` | `null` | no |
| <a name="input_gcp_cluster_custom_role"></a> [gcp\_cluster\_custom\_role](#input\_gcp\_cluster\_custom\_role) | OPTIONAL: Fully-qualified custom role name to use for cluster instances (e.g., projects/PROJECT\_ID/roles/ROLE\_ID). If set, the module will NOT create a custom role and will bind this role instead. | `string` | `null` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | GCP project | `string` | n/a | yes |
| <a name="input_gcp_provisioner_custom_role"></a> [gcp\_provisioner\_custom\_role](#input\_gcp\_provisioner\_custom\_role) | OPTIONAL: Fully-qualified custom role name to use for the provisioner instance (e.g., projects/PROJECT\_ID/roles/ROLE\_ID). If set, the module will NOT create a custom role and will bind this role instead. | `string` | `null` | no |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region | `string` | n/a | yes |
| <a name="input_gcp_subnet_name"></a> [gcp\_subnet\_name](#input\_gcp\_subnet\_name) | GCP private subnet name | `string` | n/a | yes |
| <a name="input_gcp_vpc_name"></a> [gcp\_vpc\_name](#input\_gcp\_vpc\_name) | GCP VPC name | `string` | n/a | yes |
| <a name="input_gcp_zones"></a> [gcp\_zones](#input\_gcp\_zones) | GCP zones, on or three as a comma delimited string | `string` | n/a | yes |
| <a name="input_gcs_bucket_name"></a> [gcs\_bucket\_name](#input\_gcs\_bucket\_name) | GCP bucket name | `string` | n/a | yes |
| <a name="input_gcs_bucket_prefix"></a> [gcs\_bucket\_prefix](#input\_gcs\_bucket\_prefix) | GCP bucket prefix (path).  Include a trailing slash (/) | `string` | n/a | yes |
| <a name="input_gcs_bucket_region"></a> [gcs\_bucket\_region](#input\_gcs\_bucket\_region) | GCP region the GCS bucket is hosted in | `string` | n/a | yes |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | OPTIONAL: GCP KMS encryption key resource name (full path) | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | OPTIONAL: Additional global labels | `map(string)` | `null` | no |
| <a name="input_persistent_storage_output"></a> [persistent\_storage\_output](#input\_persistent\_storage\_output) | The output of the persistent storage module. | <pre>object({<br/>    bucket_names              = list(string)<br/>    bucket_region             = string<br/>    bucket_uris               = list(string)<br/>    deployment_unique_name    = string<br/>    prevent_destroy           = bool<br/>    soft_capacity_limit       = string<br/>    soft_capacity_limit_bytes = string<br/>  })</pre> | `null` | no |
| <a name="input_q_boot_dkv_type"></a> [q\_boot\_dkv\_type](#input\_q\_boot\_dkv\_type) | OPTIONAL: Specify the type of Disk for the boot drive and dkv drives | `string` | `"pd-balanced"` | no |
| <a name="input_q_boot_drive_size"></a> [q\_boot\_drive\_size](#input\_q\_boot\_drive\_size) | Size of the boot drive for each Qumulo Instance | `number` | `256` | no |
| <a name="input_q_cluster_admin_password"></a> [q\_cluster\_admin\_password](#input\_q\_cluster\_admin\_password) | Qumulo cluster admin password | `string` | n/a | yes |
| <a name="input_q_cluster_floating_ips"></a> [q\_cluster\_floating\_ips](#input\_q\_cluster\_floating\_ips) | The number of floating ips associated with the Qumulo cluster. | `number` | `12` | no |
| <a name="input_q_cluster_fw_ingress_cidrs"></a> [q\_cluster\_fw\_ingress\_cidrs](#input\_q\_cluster\_fw\_ingress\_cidrs) | OPTIONAL: GCP additional firewall ingress CIDRs for the Qumulo cluster | `string` | `null` | no |
| <a name="input_q_cluster_name"></a> [q\_cluster\_name](#input\_q\_cluster\_name) | Qumulo cluster name | `string` | `"CNQ"` | no |
| <a name="input_q_cluster_version"></a> [q\_cluster\_version](#input\_q\_cluster\_version) | Qumulo cluster software version | `string` | `"7.6.3.1"` | no |
| <a name="input_q_debian_package"></a> [q\_debian\_package](#input\_q\_debian\_package) | Debian or RHL package | `bool` | `true` | no |
| <a name="input_q_existing_deployment_unique_name"></a> [q\_existing\_deployment\_unique\_name](#input\_q\_existing\_deployment\_unique\_name) | OPTIONAL: The deployment\_unique\_name of the previous deployed cluster you want to replace | `string` | `null` | no |
| <a name="input_q_instance_type"></a> [q\_instance\_type](#input\_q\_instance\_type) | Qumulo GCP compute engine instance type | `string` | `"z3-highmem-8-highlssd"` | no |
| <a name="input_q_node_count"></a> [q\_node\_count](#input\_q\_node\_count) | Qumulo cluster node count | `number` | `3` | no |
| <a name="input_q_package_url"></a> [q\_package\_url](#input\_q\_package\_url) | A URL accessible to the instances pointing to the qumulo-core.deb or qumulo-core.rpm for the version of Qumulo you want to install. If null, default to using the package in the bucket specified by gcs\_bucket\_name and gcs\_bucket\_prefix. | `string` | `null` | no |
| <a name="input_q_persistent_storage_type"></a> [q\_persistent\_storage\_type](#input\_q\_persistent\_storage\_type) | GCS storage class to persist data in. CNQ Hot uses hot\_gcs\_std. | `string` | `"hot_gcs_std"` | no |
| <a name="input_q_replacement_cluster"></a> [q\_replacement\_cluster](#input\_q\_replacement\_cluster) | OPTIONAL: Build a replacement cluster for an existing Terraform deployment.  This requires a new workspace with a separate state file.  This functionality enables in-service changes to the entire compute & cache front-end. | `bool` | `false` | no |
| <a name="input_q_target_node_count"></a> [q\_target\_node\_count](#input\_q\_target\_node\_count) | Qumulo cluster target node count | `number` | `null` | no |
| <a name="input_q_write_cache_iops"></a> [q\_write\_cache\_iops](#input\_q\_write\_cache\_iops) | OPTIONAL: Specify the iops for hyper-disk.  Range of 3000 to 160000. | `number` | `null` | no |
| <a name="input_q_write_cache_tput"></a> [q\_write\_cache\_tput](#input\_q\_write\_cache\_tput) | OPTIONAL: Specify the throughput, in MB/s, for hyper-disk, 140 to 2400 MB/s | `number` | `null` | no |
| <a name="input_q_write_cache_type"></a> [q\_write\_cache\_type](#input\_q\_write\_cache\_type) | OPTIONAL: Specify the type of disk to use. | `string` | `"hyperdisk-balanced"` | no |
| <a name="input_term_protection"></a> [term\_protection](#input\_term\_protection) | Enable Termination Protection | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_provisioned"></a> [cluster\_provisioned](#output\_cluster\_provisioned) | If the qprovisioner module completed secondary provisioning of the cluster = Success/Failure |
| <a name="output_deployment_unique_name"></a> [deployment\_unique\_name](#output\_deployment\_unique\_name) | The unique name for this Cloud Native Qumulo deployment |
| <a name="output_persistent_storage_bucket_names"></a> [persistent\_storage\_bucket\_names](#output\_persistent\_storage\_bucket\_names) | The GCS bucket names the cluster uses for persistent storage |
| <a name="output_provisioner"></a> [provisioner](#output\_provisioner) | Provisioner instance |
| <a name="output_qumulo_floating_ips"></a> [qumulo\_floating\_ips](#output\_qumulo\_floating\_ips) | Qumulo floating IPs for IP failover & load distribution.  Use these IPs for the A-records in your DNS. |
| <a name="output_qumulo_nodes"></a> [qumulo\_nodes](#output\_qumulo\_nodes) | Properties of the nodes in the Qumulo cluster |
| <a name="output_qumulo_primary_ips"></a> [qumulo\_primary\_ips](#output\_qumulo\_primary\_ips) | Qumulo primary IPs |
| <a name="output_qumulo_private_url_node1"></a> [qumulo\_private\_url\_node1](#output\_qumulo\_private\_url\_node1) | Link to private IP for Qumulo Cluster - Node 1 |
| <a name="output_qumulo_removed_nodes_cleanup"></a> [qumulo\_removed\_nodes\_cleanup](#output\_qumulo\_removed\_nodes\_cleanup) | Reminder to cleanup unused resources |
| <a name="output_qumulo_removed_nodes_primary_ips"></a> [qumulo\_removed\_nodes\_primary\_ips](#output\_qumulo\_removed\_nodes\_primary\_ips) | Qumulo primary IPs of removed nodes |

---

## About This Repository
This repository uses the [MIT license](LICENSE). All contents Copyright &copy; 2025 [Qumulo, Inc.](https://qumulo.com), except where specified. All trademarks are property of their respective owners.

For more information about this repository, contact [Dack Busch](https://github.com/dackbusch) and [Gokul Kupparaj](https://github.com/gokulku).
<!-- END_TF_DOCS -->