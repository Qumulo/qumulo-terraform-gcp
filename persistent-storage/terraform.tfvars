# ****************************** Required *************************************************************
# ***** Terraform Variables *****
# deployment_name                   - Any <=32 character name for the deployment. Set on first apply.  Changes are ignoreed after that to prevent unintended resource distruction. 
#                                   - All infrastructure will be tagged with the Deployment Name and a unique 11 digit alphanumeric suffix.
deployment_name = "my-storage-deployment-name"

# ***** GCP Variables *****
# gcp_project_id                    - The GCP project for the deployment
# gcp_region                        - GCP region to deploy the cluster persistent storage buckets in.  For example us-west1 or us-east1.
#                                     The GCP buckets deployed must be in the same region you plan to deploy the Qumulo cluster in.
gcp_project_id = "my-project-name"
gcp_region     = "us-west1"

# ***** Qumulo Storage Variables *****
# prevent_destroy                   - Prevent accidentally destroying non-empty buckets with Terraform.  If applied true, this must be set to false, applied, and then a destroy may be performed.
# soft_capacity_limit               - The capacity limit for all buckets combined.  Specified in TB, 500TB to 50000TB (50PB).  Default is 500TB.  You can always increase the soft limit in the future.
prevent_destroy     = false
soft_capacity_limit = 500

# ***** Misc *****
# labels                            - Additional lables to add to all created resources.  Often used for billing, departmental tracking, chargeback, etc.
#                                     If you add an additional label with the key 'name' it will be ignored.  All infrastructure is tagged with the 'name=deployment_unique_name'.
#                                        Example: tags = { "key1" = "value1", "key2" = "value2" }
labels = { "department" = "se", "owner" = "dack", "purpose" = "tf-dev", "long_running" = "false" }
