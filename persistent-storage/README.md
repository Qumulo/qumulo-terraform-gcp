<!-- BEGIN_TF_DOCS -->

<a target="_blank" href="https://qumulo.com/"><img src="./.config/images/qumulo-scale-anywhere-logo.webp" style="width:150px;height:53px;"></a>

## Terraform Documentation

> ℹ️ **Note:** This repository uses documentation generated with Terraform-Docs.  

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 6.48.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_count_override"></a> [bucket\_count\_override](#input\_bucket\_count\_override) | The number of buckets to deploy. If unset, the number of buckets is derived from the soft\_capacity\_limit variable. Requires dev\_environment=true. | `number` | `null` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name for this Terraform deployment.  This name plus 11 random alphanumeric characters will be used for all resource names where appropriate. | `string` | n/a | yes |
| <a name="input_dev_environment"></a> [dev\_environment](#input\_dev\_environment) | Disables some checks and restrictions. Leaves the provisioner running after the cluster is deployed. NOT recommended for production | `bool` | `false` | no |
| <a name="input_gcp_project_id"></a> [gcp\_project\_id](#input\_gcp\_project\_id) | GCP project | `string` | n/a | yes |
| <a name="input_gcp_region"></a> [gcp\_region](#input\_gcp\_region) | GCP region | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | OPTIONAL: Additional global labels | `map(string)` | `null` | no |
| <a name="input_log_bucket"></a> [log\_bucket](#input\_log\_bucket) | The bucket that will receive usage logs and storage logs for the buckets. Requires dev\_environment=true. | `string` | `null` | no |
| <a name="input_prevent_destroy"></a> [prevent\_destroy](#input\_prevent\_destroy) | Prevent the accidental destruction of non-empty buckets with Terraform. | `bool` | `true` | no |
| <a name="input_soft_capacity_limit"></a> [soft\_capacity\_limit](#input\_soft\_capacity\_limit) | Soft capacity limit for all buckets combined: 50TB to 50000TB (50PB). | `number` | `500` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | Names of the Google buckets created |
| <a name="output_bucket_region"></a> [bucket\_region](#output\_bucket\_region) | Region for GCS buckets |
| <a name="output_bucket_uris"></a> [bucket\_uris](#output\_bucket\_uris) | URIs for the buckets created for use with the GCS API |
| <a name="output_deployment_unique_name"></a> [deployment\_unique\_name](#output\_deployment\_unique\_name) | The unique name for this Persistent Storage deployment.  Referenced for the CNQ Cluster deployment. |
| <a name="output_prevent_destroy"></a> [prevent\_destroy](#output\_prevent\_destroy) | Prevent the accidental destruction of non-empty buckets with Terraform. |
| <a name="output_soft_capacity_limit"></a> [soft\_capacity\_limit](#output\_soft\_capacity\_limit) | Soft capacity limit for all buckets combined |
| <a name="output_soft_capacity_limit_bytes"></a> [soft\_capacity\_limit\_bytes](#output\_soft\_capacity\_limit\_bytes) | Soft capacity limit, in bytes, for all buckets combined |

---

## About This Repository
This repository uses the [MIT license](LICENSE). All contents Copyright &copy; 2025 [Qumulo, Inc.](https://qumulo.com), except where specified. All trademarks are property of their respective owners.

For more information about this repository, contact [Dack Busch](https://github.com/dackbusch) and [Gokul Kupparaj](https://github.com/gokulku).
<!-- END_TF_DOCS -->