# ****************************** Required *************************************************************
# ***** Terraform Variables *****
# deployment_name                   - Any <=18 character name for the deployment. Set on first apply.  Changes are ignoreed after that to prevent unintended resource distruction.
#                                   - All infrastructure will be tagged with the Deployment Name and a unique 7 digit alphanumeric suffix.
deployment_name = "my-deployment-name"

# ***** GCS Bucket Variables (This is NOT used for persistent storage by the filesystem, it's a utility bucket for deployment and provisioning *****
# gcs_bucket_name                    - An existing GCS Bucket to place provisioning instance files in
# gcs_bucket_prefix                  - An existing preconfigured GCS prefix, a folder. A subfolder with the deployment name is created under the supplied prefix
# gcs_bucket_region                  - Region the GCS bucket is hosted in
gcs_bucket_name   = "my-utility-bucket"
gcs_bucket_prefix = "my-terraform/"
gcs_bucket_region = "us-west1"

# ***** GCP Variables *****
# gcp_project_id                    - The GCP project for the deployment
# gcp_region                        - Region for the deployment of the cluster
# gcp_zones                         - A zone within the region
#                                     OR a comma delimited string of 3 zones, for a multi-AZ deployment
# gcp_vpc_name                      - An existing VPC name for the deployment within the provided region
# gcp_subnet_name                   - An existing GCP subnet to deploy the cluster in
# term_protection                   - true/false to enable GCE termination protection.  This should be set to 'true' for production deployments.
gcp_project_id  = "my-gcp-project"
gcp_region      = "us-west1"
gcp_zones       = "us-west1-a"
gcp_vpc_name    = "my-vpc-name"
gcp_subnet_name = "my-subnet-name"
term_protection = true

# ***** Qumulo Cluster Variables *****
# gce_image_name                    - Leave this null to look up the latest Ubuntu or Rocky image. Alternatively, this is the image name of an Ubuntu 24.04LTS (deb), or a RHL (rpm).
# q_cluster_admin_password          - Minimum 8 characters and must include one each of: uppercase, lowercase, and a special character.  If replacing a cluster make sure this password matches current running cluster.
# q_cluster_name                    - Name must be an alpha-numeric string between 2 and 15 characters. Dash (-) is allowed if not the first or last character. Must be unique per cluster.
# q_cluster_version                 - Software version.  This selects the folder within the 'qumulo-core-install' directory like: 'gcs_bucket_name'/'gcs_bucket_prefix'/qumulo-core-install/'q_cluster_version'
gce_image_name           = null
q_cluster_admin_password = "My-password123!"
q_cluster_name           = "CNQ"
q_cluster_version        = "7.6.3.1"

# ***** Qumulo Cluster Config Options *****
# tf_persistent_storage_workspace   - Terraform workspace name (no path) for the persistent-storage deployment.  This is 'default' by default whether state is local or remote for Terraform.
#                                     A reasonable default configuration for the provider.tf files is provided and should be reviewed/modified prior to Terraform init.
# q_persistent_storage_type         - CNQ Hot uses hot_gcs_std.  CNQ Cold is not yet supported.
# q_instance_type                   - >= z3-highmem-8-highlssd, >= z3-highmem-14-standardlssd, >= n2-highmem-8 or >= n2d-highmem-8.
# q_node_count                      - Total # GCE Instances in the cluster 3 to 24, or 1.
#                                     Increase this number to expand the cluster by adding nodes.
#                                     Decrease this number to destroy unused resources AFTER doing a Terraform apply with q_target_node_count to statefully remove node(s) from the cluster.
tf_persistent_storage_workspace = "default"
q_persistent_storage_type       = "hot_gcs_std"
q_instance_type                 = "z3-highmem-8-highlssd"
q_node_count                    = 3

# ****************************** Optional **************************************************************
# ***** Environment and Tag Options *****
# check_provisioner_shutdown        - Default is true.  Launches a local-exec script on the Terraform machine to validate the completion of secondary provisioning of the cluster.
# dev_environment                   - Disables some checks and restrictions. Leaves the provisioner running after the cluster is deployed. NOT recommended for production
# labels                            - Additional labels to add to all created resources.  Often used for billing, departmental tracking, chargeback, etc.
#                                     If you add an additional label with the key 'name' it will be ignored.  All infrastructure is labeled with 'name=deployment_unique_name'.
#                                        Example: labels = { "key1" = "value1", "key2" = "value2" }
check_provisioner_shutdown = true
dev_environment            = false
labels                     = null

# ***** Qumulo REMOVE Cluster Node(s) Option *****
# q_target_node_count              - Use this to remove nodes from a cluster. Leave this set to 'null' unless specifically wanting to shrink the size of the cluster.
#                                    First set q_target_node_count < q_node_count, then TF apply.
#                                    Finally, reduce q_node_count so it equals q_target_node_count. TF apply to destroy unused resrouces.
#                                    Set this variable back to 'null' after the 2nd TF apply above.
#                                    This variable is completely ignored if q_replacement_cluster=true.  Cluster replace can change instance type and node count during the compute replacement.
q_target_node_count = null

# ***** Qumulo REPLACEMENT Cluster Options *****
# q_replacement_cluster             - Deploy a new cluster, in a new Terraform Workspace (new state file), to replace an existing cluster all done in-service.  Make sure you change to a new workspace!
# q_existing_deployment_unique_name - The deployment_unique_name of the previous cluster that was deployed and is going to be replaced
q_replacement_cluster             = false
q_existing_deployment_unique_name = null

# ***** Qumulo Cluster Misc Options *****
# kms_key_name                          - Specify a KMS Customer Managed Key resource name for Persistent Disk encryption. Leave it 'null' to use a GCP managed key.
#                                         This name includes the entire path like: 'projects/<my-project>/locations/<gcp-region>/keyRings/<my-keyring>/cryptoKeys/<my-key>'
# q_cluster_fw_ingress_cidrs            - Comma delimited list of CIDRS for additional firewall ingress rules for the Qumulo cluster. 10.10.10.0/24, 10.11.30.0/24, etc
# q_cluster_floating_ips                - The number of floating IPs. Defaults to 12. Set to 0 to disable. Cannot be changed after initial deployment.
kms_key_name               = null
q_cluster_fw_ingress_cidrs = null
q_cluster_floating_ips     = 12
