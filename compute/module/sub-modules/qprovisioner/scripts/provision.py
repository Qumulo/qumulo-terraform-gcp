#!/usr/bin/env python3

# MIT License

# Copyright (c) 2025 Qumulo, Inc.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""
QProvisioner Node Provisioning Script for GCP

This script provisions and manages Qumulo clusters on Google Cloud Platform (GCP).
It performs cluster creation, node management, capacity adjustments, network configuration,
and cluster replacement operations. The script is executed via cloud-init user_data during
VM startup and logs all output to /var/log/qumulo.log. Variables are provided by Terraform
templatefile substitution.
"""

import json
import logging
import os
import re
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import urllib.request
import urllib.error


@dataclass
class ProvisioningConfig:
    """
    Configuration for GCP Qumulo cluster provisioning.
    Contains all parameters needed for cluster operations.
    """
    # Core cluster settings
    cluster_name: str
    admin_password: str

    # GCP infrastructure settings
    project: str
    region: str
    zone: str
    gcs_bucket: str
    subnet_cidr: str

    # Node configuration
    node_ips: List[str]                    # Primary IP addresses of cluster nodes
    node1_ip: str                          # IP of the first node (clustering node)
    fault_domain_ids: List[str]            # Fault domain IDs for each node
    instance_ids: List[str]                # GCP instance IDs
    target_node_count: int                 # Target number of nodes
    number_azs: int                        # Number of availability zones

    # Storage configuration
    cluster_persistent_storage_type: str   # Storage type (hot_gcs_std, etc.)
    bucket_names: List[str]                # GCS bucket names for persistent storage
    bucket_uris: List[str]                 # Full GCS bucket URIs
    capacity_limit: int                    # Soft capacity limit in bytes

    # Network configuration
    floating_ips: List[str]                # Floating IP addresses

    # Secrets and authentication
    cluster_secrets_name: str              # Secret name for cluster credentials

    # Firestore state management
    storage_deployment_name: str           # Firestore database name
    deployment_unique_name: str            # Unique deployment identifier
    existing_deployment_name: Optional[str] # For cluster replacement

    # GCS and script paths
    functions_gcs_prefix: str             # GCS prefix for function scripts
    install_gcs_prefix: str               # GCS prefix for installation files
    qumulo_package_url: str               # URL for Qumulo package download

    # Performance tunables (always provided by Terraform, may be 0)
    tun_refill_iops: int                  # IOPS refill tunable
    tun_refill_bps: int                   # Bandwidth refill tunable
    tun_disk_count: int                   # Disk count for tunables calculation
    flash_tput: int                       # Flash throughput setting
    flash_iops: int                       # Flash IOPS setting

    # Terraform operation flags
    replace_cluster: bool                 # Whether this is a cluster replacement
    dev_environment: bool                 # Whether this is a development environment

    # Optional fields (may be None/empty)
    def_password: str = "Admin123!"       # Default password for initial setup


def create_provisioning_config() -> ProvisioningConfig:
    """
    Create ProvisioningConfig from template variables.
    This function will be called after template substitution by user-data.sh.
    """
    # Parse comma-separated values into lists
    node_ips = "${primary_ips}".split(",") if "${primary_ips}" else []
    fault_domain_ids = "${fault_domain_ids}".split(",") if "${fault_domain_ids}" else []
    instance_ids = "${instance_ids}".split(",") if "${instance_ids}" else []
    floating_ips = "${floating_ips}".split(",") if "${floating_ips}" else []
    bucket_names = "${cluster_persistent_bucket_names}".split(",") if "${cluster_persistent_bucket_names}" else []
    bucket_uris = "${cluster_persistent_bucket_uris}".split(",") if "${cluster_persistent_bucket_uris}" else []

    # Handle boolean conversion
    replace_cluster = "${replacement_cluster}".lower() == "true"
    dev_environment = "${dev_environment}".lower() == "true"

    target_node_count = int("${target_node_count}")
    number_azs = int("${number_azs}")
    capacity_limit = int("${cluster_persistent_storage_capacity_limit}")
    tun_refill_iops = int("${tun_refill_IOPS}")
    tun_refill_bps = int("${tun_refill_Bps}")
    tun_disk_count = int("${tun_disk_count}")
    flash_tput = int("${flash_tput}")
    flash_iops = int("${flash_iops}")

    # Handle optional deployment name
    existing_deployment_name = "${existing_deployment_unique_name}" if "${existing_deployment_unique_name}" else None

    return ProvisioningConfig(
        # Core cluster settings
        cluster_name="${cluster_name}",
        admin_password="${temporary_password}",

        # GCP infrastructure
        project="${project}",
        region="${region}",
        zone="${zone}",
        gcs_bucket="${bucket_name}",
        subnet_cidr="${subnet_cidr}",

        # Node configuration
        node_ips=node_ips,
        node1_ip="${node1_ip}",
        fault_domain_ids=fault_domain_ids,
        instance_ids=instance_ids,
        target_node_count=target_node_count,
        number_azs=number_azs,

        # Storage configuration
        cluster_persistent_storage_type="${cluster_persistent_storage_type}",
        bucket_names=bucket_names,
        bucket_uris=bucket_uris,
        capacity_limit=capacity_limit,

        # Network configuration
        floating_ips=floating_ips,

        # Secrets
        cluster_secrets_name="${cluster_secrets_name}",

        # Firestore state management
        storage_deployment_name="${persistent_storage_deployment_unique_name}",
        deployment_unique_name="${deployment_unique_name}",
        existing_deployment_name=existing_deployment_name,

        # GCS paths
        functions_gcs_prefix="${functions_gcs_prefix}",
        install_gcs_prefix="${install_gcs_prefix}",
        qumulo_package_url="${qumulo_package_url}",

        # Performance tunables
        tun_refill_iops=tun_refill_iops,
        tun_refill_bps=tun_refill_bps,
        tun_disk_count=tun_disk_count,
        flash_tput=flash_tput,
        flash_iops=flash_iops,

        # Terraform operation flags
        replace_cluster=replace_cluster,
        dev_environment=dev_environment,
    )


class ProvisioningError(Exception):
    """Exception raised for provisioning-related errors"""
    pass


################################################################################
#                                UTILITY FUNCTIONS                            #
################################################################################


def run_command(cmd: str, timeout: Optional[int] = None, check: bool = True) -> subprocess.CompletedProcess:
    """
    Execute a shell command with proper error handling.
    """
    try:
        result = subprocess.run(
            cmd, shell=True, check=check, capture_output=True, text=True, timeout=timeout
        )
        if result.stdout.strip():
            logging.info(result.stdout.strip())
        if result.stderr.strip():
            logging.error(result.stderr.strip())
        return result
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {cmd}")
        if e.stdout and e.stdout.strip():
            logging.info(e.stdout.strip())
        if e.stderr and e.stderr.strip():
            logging.error(e.stderr.strip())
        error_msg = f"Command failed with exit code {e.returncode}: {cmd}"
        raise ProvisioningError(error_msg) from e


def gcloud_command(args: str, timeout: int = 300) -> subprocess.CompletedProcess:
    """Execute gcloud command with proper error handling"""
    cmd = f"gcloud {args}"
    return run_command(cmd, timeout=timeout)


def qq_command(args: str, host: str, timeout: int = 300) -> subprocess.CompletedProcess:
    """Execute qq command against specified host"""
    cmd = f"./qq --host {host} {args}"
    return run_command(cmd, timeout=timeout)


def set_qfsd_log_level(qq_host: str, level: str) -> None:
    """Set QFSD log level"""
    json_data = json.dumps({"level": level, "reset": False})
    cmd = f"echo '{json_data}' | ./qq --host {qq_host} raw PUT /v1/conf/log/module/%2F"
    run_command(cmd)


def chkurl(url: str, no_sec: bool = False) -> bool:
    """
    Check URL availability.
    Returns True if URL is reachable (HTTP 200), False otherwise.
    """
    try:
        k = "k" if no_sec else ""
        cmd = f'curl -sL{k} -w "%%{{http_code}}\\n" "{url}" -o /dev/null --connect-timeout 10 --retry 3 --retry-delay 5 --max-time 60'
        result = run_command(cmd, timeout=70, check=False)
        return result.stdout.strip() == "200"
    except Exception:
        return False


def getqq(ip: str, file_name: str) -> None:
    """Download qq client from specified IP"""
    cmd = f'wget --quiet --no-check-certificate -O "{file_name}" "https://{ip}/static/qq"'
    run_command(cmd)
    cmd = f'chmod 777 "./{file_name}"'
    run_command(cmd)


def getsecret(name: str, project: str) -> str:
    """Get secret from GCP Secret Manager"""
    result = gcloud_command(f'secrets versions access latest --project="{project}" --secret="{name}"')
    return result.stdout.strip()


def vercomp(version1: str, version2: str) -> int:
    """
    Version comparison function.
    Returns: 0 if equal, 1 if version1 < version2, 2 if version1 > version2
    """
    if version1 == version2:
        return 0

    # Split versions into components
    v1_parts = version1.split('.')
    v2_parts = version2.split('.')

    # Pad shorter version with zeros
    max_len = max(len(v1_parts), len(v2_parts))
    v1_parts.extend(['0'] * (max_len - len(v1_parts)))
    v2_parts.extend(['0'] * (max_len - len(v2_parts)))

    # Compare each component
    for i in range(max_len):
        v1_num = int(v1_parts[i]) if v1_parts[i].isdigit() else 0
        v2_num = int(v2_parts[i]) if v2_parts[i].isdigit() else 0

        if v1_num > v2_num:
            return 2
        elif v1_num < v2_num:
            return 1

    return 0


def wait_for_active_quorum(qq_host: str) -> None:
    """Wait for active quorum"""
    while True:
        try:
            result = qq_command("node_state_get", qq_host)
            if "ACTIVE" in result.stdout:
                logging.info("Quorum formed")
                break
        except ProvisioningError:
            pass

        time.sleep(5)
        logging.info("Waiting for Quorum")


def serialize_list_for_firestore(items: List[str]) -> str:
    return ",".join(items) if items else ""


def deserialize_list_from_firestore(value: str) -> List[str]:
    if not value or value == "null":
        return []

    return [item.strip() for item in value.split(",")]


class FirestoreManager:
    """
    Firestore operations manager using the existing firestore_vm.py client.
    Provides functionality equivalent to bash Firestore functions.
    """

    def __init__(self, config: ProvisioningConfig):
        self.config = config
        # Import the existing firestore_vm client
        import sys
        sys.path.append('/root')
        from firestore_vm import FirestoreVMClient

        self.client = FirestoreVMClient()
        self.token = None

    def gettoken(self) -> str:
        """Get Firestore authentication token"""
        if self.token is None:
            self.token = self.client.get_token(
                self.config.project,
                self.config.storage_deployment_name,
                self.config.deployment_unique_name
            )
            if not self.token:
                raise ProvisioningError("Failed to get Firestore token")
        return self.token

    def get(self, key: str, deployment_name: Optional[str] = None) -> str:
        """Get document from Firestore"""
        token = self.gettoken()
        # Use provided deployment name or default to current deployment
        deployment = deployment_name if deployment_name else self.config.deployment_unique_name
        return self.client.get_document(
            key,
            self.config.project,
            self.config.storage_deployment_name,
            deployment,
            token
        )

    def put(self, key: str, value: str) -> None:
        """Put document to Firestore"""
        token = self.gettoken()
        success = self.client.put_document(
            key,
            self.config.project,
            self.config.storage_deployment_name,
            self.config.deployment_unique_name,
            token,
            value
        )
        if not success:
            raise ProvisioningError(f"Failed to put Firestore document: {key}")

    def update_status(self, status: str) -> None:
        """Log status with timestamp to Firestore"""
        token = self.gettoken()
        success = self.client.put_status_with_timestamp(
            self.config.project,
            self.config.storage_deployment_name,
            self.config.deployment_unique_name,
            token,
            status
        )
        if not success:
            raise ProvisioningError(f"Failed to put Firestore status: {status}")

    def put_list(self, key: str, value_list: List[str]) -> None:
        """Put a list to Firestore using standardized serialization"""
        serialized_value = serialize_list_for_firestore(value_list)
        self.put(key, serialized_value)

    def get_list(self, key: str, deployment_name: Optional[str] = None) -> List[str]:
        """Get a list from Firestore using standardized deserialization"""
        value = self.get(key, deployment_name)
        return deserialize_list_from_firestore(value)


def log_status_to_firestore(firestore: FirestoreManager, message: str) -> None:
    """Log status message to Firestore"""
    firestore.update_status(message)


def apply_cluster_tunables(qq_host: str, refill_iops: int, refill_bps: int, disk_count: int) -> None:
    """Apply cluster tunables"""
    calc_refill_bps = 0

    if refill_iops != 0:
        json_data = json.dumps({"configured_value": str(refill_iops)})
        cmd = f"echo '{json_data}' | ./qq --host {qq_host} raw PUT /v1/tunables/credit_accountant_io_refill_iops"
        run_command(cmd)

    if refill_bps != 0 and disk_count != 0:
        calc_refill_bps = (refill_bps * 1000 * 1000) // 4096
        json_data = json.dumps({"configured_value": str(calc_refill_bps)})
        cmd = f"echo '{json_data}' | ./qq --host {qq_host} raw PUT /v1/tunables/credit_accountant_th_refill_blocks_per_second"
        run_command(cmd)

    qq_command("raw POST /v1/debug/quorum/abandon-series", qq_host)
    logging.info("Bouncing quorum to apply tunables")
    wait_for_active_quorum(qq_host)
    set_qfsd_log_level(qq_host, "QM_LOG_INFO")


################################################################################
#                         ENVIRONMENT SETUP AND VALIDATION                    #
################################################################################


def install_firestore_dependencies(config: ProvisioningConfig) -> None:
    """
    Install Python dependencies for Firestore operations.
    Downloads and installs required scripts and dependencies.
    """
    gcs_bucket = config.gcs_bucket
    functions_gcs_prefix = config.functions_gcs_prefix

    # Update system packages
    run_command("apt-get update")

    # Download and install Python Firestore utilities
    if not os.path.exists("install_vm_deps.sh"):
        gcloud_command(f'storage cp "gs://{gcs_bucket}/{functions_gcs_prefix}install_vm_deps.sh" ./install_vm_deps.sh')
        run_command("chmod +x install_vm_deps.sh")

    if not os.path.exists("python_installer.sh"):
        gcloud_command(f'storage cp "gs://{gcs_bucket}/{functions_gcs_prefix}python_installer.sh" ./python_installer.sh')
        run_command("chmod +x python_installer.sh")

    if not os.path.exists("firestore_vm.py"):
        gcloud_command(f'storage cp "gs://{gcs_bucket}/{functions_gcs_prefix}firestore_vm.py" ./firestore_vm.py')
        run_command("chmod +x firestore_vm.py")

    if not os.path.exists("requirements.txt"):
        gcloud_command(f'storage cp "gs://{gcs_bucket}/{functions_gcs_prefix}requirements.txt" ./requirements.txt')

    # Install Python and verify all dependencies
    run_command(f"./install_vm_deps.sh \"{gcs_bucket}\" \"{functions_gcs_prefix}\"")


def validate_connectivity(firestore: FirestoreManager) -> None:
    """Validate internet and MQ connectivity"""
    # Check to make sure MQ is reachable
    if chkurl("https://api.missionq.qumulo.com/"):
        firestore.update_status("BOOTED. MQ up for metrics.")
    else:
        firestore.update_status("BOOTED. MQ NOT reachable. Aborting deployment.")
        raise ProvisioningError("MQ not reachable")

    time.sleep(2)

    # Check to make sure the internet is reachable
    if chkurl("https://google.com"):
        firestore.update_status("BOOTED. Internet up.")
    else:
        firestore.update_status("BOOTED. Internet NOT reachable. NAT or VPC endpoints are required.")

    time.sleep(2)


def install_required_packages() -> None:
    """Install packages required for script execution"""

    result = run_command("apt list --installed jq", check=False)
    if result.returncode != 0 or "jq" not in result.stdout:
        logging.info("Installing jq")
        run_command("apt-get install -y jq")
    else:
        logging.info("jq exists")

    result = run_command("apt list --installed wget", check=False)
    if result.returncode != 0 or "wget" not in result.stdout:
        logging.info("Installing wget")
        run_command("apt-get install -y wget")
    else:
        logging.info("wget exists")


def setup_admin_password(config: ProvisioningConfig, firestore: FirestoreManager) -> str:
    """
    Setup admin password based on cluster replacement status.
    Returns the actual admin password to use for operations.
    """
    if config.replace_cluster:
        # For replacement cluster, use previous cluster's admin password
        existing_secrets_name = firestore.get("cluster-secrets-name", config.existing_deployment_name)
        admin_password = getsecret(existing_secrets_name, config.project)
        # Write password to new deployment's secrets
        run_command(f'echo -n "{admin_password}" | gcloud secrets versions add {config.cluster_secrets_name} --project={config.project} --data-file=-')
    else:
        # For new cluster, get password from secrets
        admin_password = getsecret(config.cluster_secrets_name, config.project)

    return admin_password


def wait_for_nodes_ready(config: ProvisioningConfig, firestore: FirestoreManager) -> None:
    """Wait for all nodes to boot and run Qumulo Core"""
    firestore.update_status(f"Waiting for node 1 to run Qumulo Core. Package location: {config.qumulo_package_url}")

    for i, node_ip in enumerate(config.node_ips):
        if i == 1:  # After first node
            firestore.update_status("Qumulo Core running on node 1. Waiting for other nodes to run Qumulo Core.")

        # Wait for node to be reachable
        while not chkurl(f"https://{node_ip}:8000/v1/node/state", no_sec=True):
            time.sleep(5)
            logging.info(f"Waiting for {node_ip} to boot")

        # Download qq client from first node
        if i == 0:
            getqq(node_ip, "qq")


def get_qfsd_version(node_ip: str) -> str:
    """Get Qumulo Core version from specified node"""
    result = qq_command("version", node_ip)
    for line in result.stdout.split('\n'):
        if "revision_id" in line:
            # Extract version number (remove non-numeric/period characters)
            return re.sub(r'[^0-9.]', '', line)
    return ""


def survey_cluster_state(config: ProvisioningConfig, firestore: FirestoreManager) -> Tuple[int, int, str]:
    """
    Survey cluster state and return quorum information.
    Returns: (out_quorum_count, in_quorum_count, qfsd_version)
    """
    out_quorum = 0
    in_quorum = 0
    qfsd_version = ""

    firestore.update_status("Checking quorum state and boot status")

    for i, node_ip in enumerate(config.node_ips):
        # Check quorum status
        try:
            result = qq_command("node_state_get", node_ip)
            quorum_status = result.stdout

            if "ACTIVE" not in quorum_status:
                out_quorum += 1
            else:
                in_quorum += 1

        except ProvisioningError:
            out_quorum += 1

    # Get version from first node
    if config.node_ips:
        qfsd_version = get_qfsd_version(config.node_ips[0])

    firestore.update_status(f"Qumulo Core version {qfsd_version} running on all {len(config.node_ips)} nodes.")
    firestore.put("installed-version", qfsd_version)

    org_ver = firestore.get("creation-version")
    if org_ver == "null":
        firestore.put("creation-version", qfsd_version)

    return out_quorum, in_quorum, qfsd_version


def validate_qfsd_version(qfsd_version: str, firestore: FirestoreManager) -> None:
    """Validate that Qumulo Core version meets minimum requirements"""
    # Check for version greater than 7.6.0 to support CNQ on GCP
    check_version = vercomp(qfsd_version, "7.6.0")
    if check_version == 0 or check_version == 2:  # qfsd_version >= 7.6.0
        logging.info("Qumulo Core >= 7.6.0")
    else:
        error_msg = "Qumulo Core version >= 7.6.0 is required. If this is a new deployment destroy it and redeploy with >= 7.6.0."
        logging.error(error_msg)
        firestore.update_status(error_msg)
        raise ProvisioningError(error_msg)


def parse_quorum_details(qq_host: str) -> Tuple[List[str], List[str], List[str]]:
    """
    Parse quorum details from cluster.
    Returns: (all_nodes, in_nodes, out_nodes)
    """
    result = qq_command("raw GET /v1/debug/quorum/details", qq_host)
    quorum_details = result.stdout

    # Extract node lists using regex
    all_nodes_match = re.search(r'"all_nodes":\s*\[(.*?)\]', quorum_details)
    in_nodes_match = re.search(r'"in_nodes":\s*\[(.*?)\]', quorum_details)
    out_nodes_match = re.search(r'"out_nodes":\s*\[(.*?)\]', quorum_details)

    def parse_node_list(match) -> List[str]:
        if match:
            nodes_str = match.group(1).strip()
            if nodes_str:
                # Split by comma and strip whitespace/quotes
                return [node.strip(' "') for node in nodes_str.split(',')]
        return []

    all_nodes = parse_node_list(all_nodes_match)
    in_nodes = parse_node_list(in_nodes_match)
    out_nodes = parse_node_list(out_nodes_match)

    return all_nodes, in_nodes, out_nodes


def initialize_and_validate(config: ProvisioningConfig, firestore: FirestoreManager) -> Tuple[str, str, str]:
    """
    Complete environment setup and validation.
    Returns: (firestore_manager, admin_password, qfsd_version, operation_flags)
    """
    # Initialize Firestore last-run-status if first run
    last_run_status = firestore.get("last-run-status")
    if last_run_status == "null":
        firestore.update_status("null")  # This will create the timestamped document structure

    validate_connectivity(firestore)

    firestore.update_status("Installing jq and reading secrets")
    install_required_packages()
    admin_password = setup_admin_password(config, firestore)

    wait_for_nodes_ready(config, firestore)
    out_quorum, in_quorum, qfsd_version = survey_cluster_state(config, firestore)
    validate_qfsd_version(qfsd_version, firestore)

    return admin_password, out_quorum, in_quorum


################################################################################
#                      DETERMINE CLUSTER OPERATIONS                            #
################################################################################


def determine_cluster_operations(config: ProvisioningConfig, firestore: FirestoreManager,
                               out_quorum: int, in_quorum: int, admin_password: str) -> Dict[str, bool]:
    """
    Determine what cluster operations are needed based on current state.
    Returns dictionary of operation flags.
    """
    operation_flags = {
        "new_cluster": False,
        "add_nodes": False,
        "remove_nodes": False,
        "add_buckets": False,
        "increase_limit": False
    }

    logging.info("=== DETERMINING CLUSTER OPERATIONS ===")
    logging.info(f"Quorum status: {in_quorum} in quorum, {out_quorum} out of quorum")
    logging.info(f"Replace cluster: {config.replace_cluster}")

    if out_quorum == len(config.node_ips) and in_quorum == 0:
        # All nodes out of quorum - new cluster
        logging.info("DECISION: NEW CLUSTER (all nodes out of quorum)")
        firestore.update_status("All nodes out of quorum, NEW CLUSTER")
        operation_flags["new_cluster"] = True
    else:
        # Existing cluster - need to login and check detailed quorum status
        logging.info("DECISION: EXISTING CLUSTER detected")
        qq_host = config.node1_ip
        qq_command(f"login -u admin -p {admin_password}", qq_host)

        # Parse detailed quorum information
        all_nodes, in_nodes, out_nodes = parse_quorum_details(qq_host)

        if len(out_nodes) > 0:
            error_msg = "One or more nodes out of quorum in existing cluster. Rectify and restart the provisioner instance."
            logging.error(error_msg)
            firestore.update_status(error_msg)
            raise ProvisioningError(error_msg)

        firestore.update_status("Cluster in full quorum, checking for node add, node delete, and bucket additions")

        # Check for node changes
        old_ips_str = firestore.get("node-ips")
        logging.info(f"old_ips_str: {old_ips_str}")
        if old_ips_str != "null":
            old_ips = firestore.get_list("node-ips")
            new_ips = config.node_ips

            # Check for new nodes to add
            upgrade_ips = [ip for ip in new_ips if ip not in old_ips]
            if upgrade_ips:
                logging.info(f"DECISION: ADD NODES - {upgrade_ips}")
                # Validate version consistency for new nodes
                add_ver = get_qfsd_version(upgrade_ips[0])
                current_ver = firestore.get("installed-version")
                if current_ver != add_ver:
                    error_msg = f"Cluster is running ver={current_ver}. Can't add nodes running ver={add_ver}. Update CloudFormation or Terraform with previous node count to remove these nodes. Exiting."
                    firestore.update_status(error_msg)
                    raise ProvisioningError(error_msg)
                operation_flags["add_nodes"] = True

            # Check for nodes to remove
            if len(old_ips) > config.target_node_count:
                nodes_to_remove = len(old_ips) - config.target_node_count
                logging.info(f"DECISION: REMOVE NODES - removing {nodes_to_remove} nodes")
                operation_flags["remove_nodes"] = True

    # Check for bucket changes
    if config.replace_cluster:
        # For replacement, get bucket info from EXISTING deployment
        old_bucket_names = firestore.get_list("bucket-names", config.existing_deployment_name)
        old_bucket_uris = firestore.get_list("bucket-uris", config.existing_deployment_name)
        old_limit_str = firestore.get("soft-capacity-limit", config.existing_deployment_name)
    else:
        old_bucket_names = firestore.get_list("bucket-names")
        old_bucket_uris = firestore.get_list("bucket-uris")
        old_limit_str = firestore.get("soft-capacity-limit")

    # Only check for bucket additions if NOT a new cluster OR if cluster replacement
    if not operation_flags["new_cluster"] or config.replace_cluster:
        new_bucket_names = [name for name in config.bucket_names if name not in old_bucket_names]
        new_bucket_uris = [uri for uri in config.bucket_uris if uri not in old_bucket_uris]
        if new_bucket_names and new_bucket_uris:
            logging.info(f"DECISION: ADD BUCKETS - {new_bucket_names}")
            operation_flags["add_buckets"] = True

        # Check for capacity limit increase
        if old_limit_str != "null":
            old_limit = int(old_limit_str)
            if config.capacity_limit > old_limit and not operation_flags["add_buckets"]:
                logging.info(f"DECISION: INCREASE CAPACITY - from {old_limit} to {config.capacity_limit}")
                operation_flags["increase_limit"] = True

    # Log final decisions
    enabled_ops = [op for op, enabled in operation_flags.items() if enabled]
    if enabled_ops:
        logging.info(f"OPERATIONS TO EXECUTE: {', '.join(enabled_ops)}")
    else:
        logging.info("OPERATIONS TO EXECUTE: None")

    return operation_flags


################################################################################
#                            EXECUTE CLUSTER OPERATIONS                       #
################################################################################


def check_buckets_empty(bucket_names: List[str], project: str) -> None:
    """Check that all buckets are empty before cluster operations"""
    for bucket_name in bucket_names:
        result = gcloud_command(f'storage objects list "gs://{bucket_name}" --project={project} --limit=1')
        if result.stdout.strip():
            error_msg = f"**BUCKET NOT EMPTY, Exiting. Empty bucket(s) and restart provisioner."
            logging.error(f"  {error_msg}")
            raise ProvisioningError(f"Bucket {bucket_name} NOT EMPTY. Empty bucket(s) and restart provisioner.")
        else:
            logging.info(f"  **BUCKET {bucket_name} EMPTY")


def get_storage_product_type(storage_type: str) -> Tuple[str, str, str]:
    """
    Map storage type to product type, S3 type, and CNQ type.
    Returns: (product_type, s3_type, cnq_type)
    """
    storage_mapping = {
        "hot_gcs_std": ("ACTIVE_WITH_STANDARD_STORAGE", "Standard", "Hot"),
        "hot_s3_int": ("ACTIVE_WITH_INTELLIGENT_STORAGE", "Intelligent Tiering", "Hot"),
        "cold_s3_ia": ("ARCHIVE_WITH_IA_STORAGE", "Infrequent Access", "Cold"),
        "cold_s3_gir": ("ARCHIVE_WITH_GIR_STORAGE", "Glacier Instant Retrieval", "Cold")
    }

    if storage_type not in storage_mapping:
        raise ProvisioningError(f"Unknown storage type: {storage_type}")

    return storage_mapping[storage_type]


def create_new_cluster(config: ProvisioningConfig, firestore: FirestoreManager, admin_password: str) -> None:
    """Create new cluster from scratch"""
    # Make sure buckets are empty
    check_buckets_empty(config.bucket_names, config.project)

    # Get product type mapping
    product_type, s3_type, cnq_type = get_storage_product_type(config.cluster_persistent_storage_type)

    # Prepare modified bucket URIs
    mod_bucket_uris = config.bucket_uris.copy()

    # Prepare node IPs and fault domains
    node_ips_fault_ids = [f"{ip},{fid}" for ip, fid in zip(config.node_ips, config.fault_domain_ids)]

    qq_host = config.node1_ip

    firestore.update_status(f"Forming first quorum and configuring cluster with {len(config.node_ips)} nodes")

    set_qfsd_log_level(qq_host, "QM_LOG_DEBUG")

    # Log cluster formation parameters
    logging.info("Quorum Formation Parameters")
    logging.info("eula_accepted: true")
    logging.info(f"cluster_name: {config.cluster_name}")
    logging.info(f"node_ips_fault_ids: [{', '.join(node_ips_fault_ids)}]")
    logging.info(f"fault_domain_ids: [{','.join(config.fault_domain_ids)}]")
    logging.info(f"admin_password: {config.def_password}")
    logging.info(f"host_instance_id: {config.def_password}")
    logging.info(f"object_storage_uris: [{', '.join(mod_bucket_uris)}]")
    logging.info(f"usable_capacity_clamp: {config.capacity_limit}")
    logging.info(f"product_type: {product_type}")

    # Create cluster command
    cluster_args = [
        "create_object_backed_cluster",
        f"--cluster-name {config.cluster_name}",
        f"--admin-password {config.def_password}",
        "--accept-eula",
        f"--host-instance-id {config.admin_password}",  # Using temporary_password from config
        f"--product-type {product_type}",
        f"--object-storage-uris {' '.join(mod_bucket_uris)}",
        f"--node-ips-and-fault-domains {' '.join(node_ips_fault_ids)}",
        f"--usable-capacity-clamp {config.capacity_limit}"
    ]

    qq_command(" ".join(cluster_args), qq_host)
    wait_for_active_quorum(qq_host)

    # Get cluster UUID
    result = qq_command("node_state_get", qq_host)
    cluster_id_line = [line for line in result.stdout.split('\n') if 'cluster_id' in line][0]
    uuid = cluster_id_line.replace('cluster_id: ', '').replace('"', '').replace(',', '').strip()

    # Store cluster metadata in Firestore
    firestore.put("uuid", uuid)
    firestore.put_list("node-ips", config.node_ips)
    firestore.put_list("fault-domain-ids", config.fault_domain_ids)
    firestore.put_list("instance-ids", config.instance_ids)
    firestore.put("creation-number-azs", str(config.number_azs))
    firestore.put("cluster-type", f"CNQ={cnq_type}, GCS={s3_type}")
    firestore.put("soft-capacity-limit", str(config.capacity_limit))
    firestore.put_list("bucket-uris", config.bucket_uris)
    firestore.put_list("bucket-names", config.bucket_names)
    firestore.put("new-cluster", "false")

    firestore.update_status("Setting cluster tunables if necessary")

    # Login with default password
    qq_command(f"login -u admin -p {config.def_password}", qq_host)

    # Apply cluster tunables
    apply_cluster_tunables(qq_host, config.tun_refill_iops, config.tun_refill_bps, config.tun_disk_count)

    # Store tunables info in Firestore
    calc_refill_bps = (config.tun_refill_bps * 1000 * 1000) // 4096 if config.tun_refill_bps != 0 and config.tun_disk_count != 0 else 0
    firestore.put("tunables", f"refill_IOPS={config.tun_refill_iops}, refill_Bps={calc_refill_bps}")

    if config.dev_environment:
        qq_command("set_monitoring_conf --mq-host staging-missionq.qumulo.com --nexus-host api.spog-staging.qumulo.com", qq_host)

    # Apply floating IPs
    apply_initial_floating_ips(config, qq_host, firestore)

    # Change to actual admin password
    qq_command(f"change_password -o {config.def_password} -p {admin_password}", qq_host)


def replace_existing_cluster(config: ProvisioningConfig, firestore: FirestoreManager, admin_password: str) -> None:
    """Replace existing cluster nodes"""
    # Prepare node IPs and fault domains
    node_ips_fault_ids = [f"{ip},{fid}" for ip, fid in zip(config.node_ips, config.fault_domain_ids)]

    # Get existing cluster information
    existing_ips_str = firestore.get("node-ips", config.existing_deployment_name)
    existing_ids_str = firestore.get("instance-ids", config.existing_deployment_name)

    if existing_ips_str == "null" or existing_ids_str == "null":
        raise ProvisioningError("Cannot find existing cluster information for replacement")

    existing_ips = firestore.get_list("node-ips", config.existing_deployment_name)
    existing_ids = firestore.get_list("instance-ids", config.existing_deployment_name)

    firestore.update_status("Detected CLUSTER REPLACE. Updating firewall rule for internode communication and detecting node IDs.")

    # Update firewall rules for internode communication
    if config.existing_deployment_name:
        gcloud_command(f'compute firewall-rules update {config.existing_deployment_name}-qumulo-internal '
                      f'--source-tags={config.existing_deployment_name}-cluster,{config.deployment_unique_name}-cluster '
                      f'--target-tags={config.existing_deployment_name}-cluster,{config.deployment_unique_name}-cluster')

    # Get Qumulo node IDs from existing cluster
    existing_node_ids = []
    for existing_ip in existing_ips:
        result = qq_command("node_state_get", existing_ip.strip())
        node_id_line = [line for line in result.stdout.split('\n') if 'node_id' in line][0]
        qid = re.sub(r'[^0-9.]', '', node_id_line)
        existing_node_ids.append(qid)
        logging.info(f"node_id={qid}")

    firestore.update_status("Detected CLUSTER REPLACE. Adding new nodes to quorum and removing existing nodes from quorum.")

    # Execute cluster replacement
    qq_command(f"login -u admin -p {admin_password}", existing_ips[0].strip())
    set_qfsd_log_level(existing_ips[0].strip(), "QM_LOG_DEBUG")
    qq_command(f"modify_object_backed_cluster_membership --node-ips-and-fault-domains {' '.join(node_ips_fault_ids)} --batch", existing_ips[0].strip())

    firestore.update_status("Detected CLUSTER REPLACE. Waiting for new quorum.")

    qq_host = config.node1_ip
    wait_for_active_quorum(qq_host)

    time.sleep(1)

    firestore.update_status("Detected CLUSTER REPLACE. New quorum formed, validating node replacement.")

    # Validate node replacement
    while True:
        all_nodes, in_nodes, out_nodes = parse_quorum_details(qq_host)
        if (len(all_nodes) == len(config.node_ips) and
            len(in_nodes) == len(config.node_ips) and
            len(out_nodes) == 0):
            break
        time.sleep(10)

    # Verify old nodes are removed
    all_nodes, _, _ = parse_quorum_details(qq_host)
    for node_id in all_nodes:
        if node_id in existing_node_ids:
            error_msg = f"**Old Node: {node_id} not removed from quorum. Slack Support."
            logging.error(error_msg)
            raise ProvisioningError(error_msg)

    firestore.update_status(f"Detected CLUSTER REPLACE: New quorum formed with {len(config.node_ips)} new nodes as requested.")

    # Get existing cluster type
    existing_cluster_type = firestore.get("cluster-type", config.existing_deployment_name)

    # Get new cluster UUID
    result = qq_command("node_state_get", qq_host)
    cluster_id_line = [line for line in result.stdout.split('\n') if 'cluster_id' in line][0]
    uuid = cluster_id_line.replace('cluster_id: ', '').replace('"', '').replace(',', '').strip()

    # Store updated cluster metadata
    firestore.put("uuid", uuid)
    firestore.put_list("node-ips", config.node_ips)
    firestore.put_list("fault-domain-ids", config.fault_domain_ids)
    firestore.put_list("instance-ids", config.instance_ids)
    firestore.put("creation-number-azs", str(config.number_azs))
    firestore.put("cluster-type", existing_cluster_type)
    firestore.put("soft-capacity-limit", str(config.capacity_limit))
    firestore.put_list("bucket-uris", config.bucket_uris)
    firestore.put_list("bucket-names", config.bucket_names)

    qq_command(f"login -u admin -p {admin_password}", qq_host)

    # Update floating IPs
    maybe_update_floating_ips(config, qq_host, firestore)
    firestore.put("new-cluster", "false")

    firestore.update_status("Setting cluster tunables if necessary")
    apply_cluster_tunables(qq_host, config.tun_refill_iops, config.tun_refill_bps, config.tun_disk_count)


def add_cluster_nodes(config: ProvisioningConfig, firestore: FirestoreManager, upgrade_ips: List[str]) -> None:
    """Add nodes to existing cluster"""
    qq_host = config.node1_ip

    firestore.update_status(f"Quorum already exists, adding nodes to cluster ({len(config.node_ips)} total nodes)")

    # Prepare node IPs and fault domains
    node_ips_fault_ids = [f"{ip},{fid}" for ip, fid in zip(config.node_ips, config.fault_domain_ids)]

    qq_command(f"modify_object_backed_cluster_membership --node-ips-and-fault-domains {' '.join(node_ips_fault_ids)} --batch", qq_host)

    wait_for_active_quorum(upgrade_ips[0])

    # Update stored metadata
    firestore.put_list("node-ips", config.node_ips)
    firestore.put_list("fault-domain-ids", config.fault_domain_ids)
    firestore.put_list("instance-ids", config.instance_ids)


def remove_cluster_nodes(config: ProvisioningConfig, firestore: FirestoreManager) -> None:
    """Remove nodes from existing cluster"""
    qq_host = config.node1_ip

    # Get existing node IDs
    existing_node_ids = []
    for node_ip in config.node_ips:
        result = qq_command("node_state_get", node_ip)
        node_id_line = [line for line in result.stdout.split('\n') if 'node_id' in line][0]
        qid = re.sub(r'[^0-9.]', '', node_id_line)
        existing_node_ids.append(qid)
        logging.info(f"node_id={qid}")

    # Calculate remaining nodes
    remaining_node_ips = config.node_ips[:config.target_node_count]
    remaining_fault_ids = config.fault_domain_ids[:config.target_node_count]
    remaining_instance_ids = config.instance_ids[:config.target_node_count]
    removed_node_ids = existing_node_ids[config.target_node_count:]

    firestore.update_status(f"Quorum already exists, removing {len(removed_node_ids)} nodes from cluster.")

    # Prepare remaining node IPs and fault domains
    node_ips_fault_ids = [f"{ip},{fid}" for ip, fid in zip(remaining_node_ips, remaining_fault_ids)]

    qq_command(f"modify_object_backed_cluster_membership --node-ips-and-fault-domains {' '.join(node_ips_fault_ids)} --batch", qq_host)

    wait_for_active_quorum(qq_host)

    firestore.update_status("New quorum formed, validating node removal.")

    # Validate node removal
    while True:
        all_nodes, in_nodes, out_nodes = parse_quorum_details(qq_host)
        if (len(all_nodes) == len(remaining_node_ips) and
            len(in_nodes) == len(remaining_node_ips) and
            len(out_nodes) == 0):
            break
        time.sleep(10)

    # Verify removed nodes are actually removed
    all_nodes, _, _ = parse_quorum_details(qq_host)
    for node_id in all_nodes:
        if node_id in removed_node_ids:
            error_msg = f"**Old Node: {node_id} not removed from quorum. Slack Support."
            logging.error(error_msg)
            raise ProvisioningError(error_msg)

    firestore.update_status(f"New quorum formed with {len(remaining_node_ips)} node(s) as requested.")

    # Update stored metadata
    firestore.put_list("node-ips", remaining_node_ips)
    firestore.put_list("fault-domain-ids", remaining_fault_ids)
    firestore.put_list("instance-ids", remaining_instance_ids)


def apply_initial_floating_ips(config: ProvisioningConfig, qq_host: str, firestore: FirestoreManager) -> None:
    """Apply initial floating IP configuration"""

    logging.info(f"Applying initial floating IPs: {config.floating_ips}")
    if not config.floating_ips or not config.floating_ips[0]:
        return

    flips_json = ", ".join(f'"{ip}"' for ip in config.floating_ips)

    logging.info(f"Setting initial floating IPs to {flips_json}")

    network_config = {
        "frontend_networks": [
            {
                "id": 1,
                "name": "default",
                "addresses": {
                    "type": "HOST",
                    "host_addresses": {
                        "floating_ip_ranges": config.floating_ips,
                        "netmask": config.subnet_cidr
                    }
                }
            }
        ]
    }

    # Write config to file and apply
    with open("network_config.json", "w") as f:
        json.dump(network_config, f)

    qq_command("network_v3_put_config --file network_config.json", qq_host)

    # Wait for network configuration to apply
    while True:
        try:
            result = qq_command("network_v3_status", qq_host)
            if "floating_addresses" in result.stdout:
                logging.info("Network configuration applied")
                break
        except ProvisioningError:
            pass

        time.sleep(5)
        logging.info("Waiting for network configuration to apply")

    firestore.update_status(f"Successfully applied {len(config.floating_ips)} floating IPs: {config.floating_ips}")

    firestore.put_list("float-ips", config.floating_ips)
    firestore.put("floating-ip-count", str(len(config.floating_ips)))


def maybe_update_floating_ips(config: ProvisioningConfig, qq_host: str, firestore: FirestoreManager) -> None:
    """Update floating IPs if they have changed"""
    # Get current network configuration
    qq_command("network_v3_get_config -o network_config.json", qq_host)

    with open("network_config.json", "r") as f:
        current_config = json.load(f)

    # Check if no floating IPs are configured
    frontend_networks_length = len(current_config.get("frontend_networks", []))
    floating_ip_count = 0
    if frontend_networks_length > 0:
        floating_ip_count = len(current_config["frontend_networks"][0]
                                .get("addresses", {})
                                .get("host_addresses", {})
                                .get("floating_ip_ranges", []))

    if frontend_networks_length == 0 or floating_ip_count == 0:
        logging.info("No floating IPs configured, applying initial floating IPs")
        apply_initial_floating_ips(config, qq_host, firestore)
        return

    current_flips = current_config["frontend_networks"][0]["addresses"]["host_addresses"]["floating_ip_ranges"]
    new_flips = config.floating_ips

    # Compare current vs new floating IPs
    if current_flips != new_flips:
        new_flips_json = ", ".join(f'"{ip}"' for ip in new_flips)
        logging.info(f"Updating floating IPs to {new_flips_json}")

        if not new_flips or not new_flips[0]:
            current_config["frontend_networks"] = []
        else:
            current_config["frontend_networks"][0]["addresses"]["host_addresses"]["floating_ip_ranges"] = new_flips

        with open("network_config.json", "w") as f:
            json.dump(current_config, f)

        qq_command("network_v3_put_config --file network_config.json", qq_host)
        firestore.update_status(f"Successfully updated {len(new_flips)} floating IPs: {new_flips}")

        firestore.put_list("float-ips", new_flips)
        firestore.put("floating-ip-count", str(len(new_flips)))
    else:
        logging.info("No change in floating IPs")


def add_object_buckets(config: ProvisioningConfig, firestore: FirestoreManager, qq_host: str) -> None:
    """Add new object storage buckets to the cluster"""

    if config.replace_cluster:
        old_bucket_names = firestore.get_list("bucket-names", config.existing_deployment_name)
        old_bucket_uris = firestore.get_list("bucket-uris", config.existing_deployment_name)
    else:
        old_bucket_names = firestore.get_list("bucket-names")
        old_bucket_uris = firestore.get_list("bucket-uris")

    new_bucket_names = [name for name in config.bucket_names if name not in old_bucket_names]
    new_bucket_uris = [uri for uri in config.bucket_uris if uri not in old_bucket_uris]

    check_buckets_empty(new_bucket_names, config.project)

    firestore.update_status(f"Adding {len(new_bucket_names)} buckets for persistent storage")

    set_qfsd_log_level(qq_host, "QM_LOG_DEBUG")
    logging.info("Bucket Add Parameters")
    logging.info(f"object_storage_uris: [{', '.join(new_bucket_uris)}]")
    logging.info(f"usable_capacity_clamp: {config.capacity_limit}")

    qq_command(f"add_object_storage_uris --uris {' '.join(new_bucket_uris)}", qq_host)
    logging.info("Buckets added")

    firestore.put_list("bucket-uris", config.bucket_uris)
    firestore.put_list("bucket-names", config.bucket_names)

    # Update capacity limit after adding buckets
    update_capacity_limit(config, firestore, qq_host)


def update_capacity_limit(config: ProvisioningConfig, firestore: FirestoreManager, qq_host: str) -> None:
    """Update the soft capacity limit"""
    firestore.update_status(f"Increasing soft capacity limit to {config.capacity_limit}")

    set_qfsd_log_level(qq_host, "QM_LOG_DEBUG")
    logging.info(f"usable_capacity_clamp: {config.capacity_limit}")

    qq_command(f"capacity_clamp_set --clamp {config.capacity_limit}", qq_host)

    logging.info("Soft capacity limit increased")
    wait_for_active_quorum(qq_host)

    set_qfsd_log_level(qq_host, "QM_LOG_INFO")

    firestore.put("soft-capacity-limit", str(config.capacity_limit))


def update_instance_labels(config: ProvisioningConfig) -> None:
    """Update GCP instance labels with node IDs"""
    firestore = FirestoreManager(config)
    firestore.update_status("Updating cluster labels")

    for i, instance_id in enumerate(config.instance_ids):
        node_number = i + 1
        node_ip = config.node_ips[i]

        # Get node ID from cluster
        result = qq_command("node_state_get", node_ip)
        node_id_line = [line for line in result.stdout.split('\n') if 'node_id' in line][0]
        qid = re.sub(r'[^0-9]', '', node_id_line)  # Remove non-numeric characters

        # Get instance zone
        zone_result = gcloud_command(f'compute instances list --project={config.project} --filter="id=( {instance_id} )" --format="value(zone)"')
        zone = zone_result.stdout.strip()

        # Update instance labels
        gcloud_command(f'compute instances update {config.deployment_unique_name}-node-{node_number} '
                      f'--project={config.project} --zone={zone} '
                      f'--update-labels=name={config.deployment_unique_name}-node-{node_number}-{qid}')


def execute_cluster_operations(config: ProvisioningConfig, firestore: FirestoreManager,
                              admin_password: str, operation_flags: Dict[str, bool]) -> None:
    """Execute the determined cluster operations in correct order"""
    qq_host = config.node1_ip

    if operation_flags["new_cluster"]:
        if config.replace_cluster:
            logging.info("EXECUTING: Cluster replacement")
            replace_existing_cluster(config, firestore, admin_password)
        else:
            logging.info("EXECUTING: New cluster creation")
            create_new_cluster(config, firestore, admin_password)
    else:
        # Existing cluster modifications
        if config.replace_cluster:
            error_msg = "Cannot replace cluster without deploying new nodes"
            logging.error(error_msg)
            raise ProvisioningError(error_msg)

        qq_command(f"login -u admin -p {admin_password}", qq_host)

        if operation_flags["add_nodes"]:
            logging.info("EXECUTING: Add nodes operation")
            # Get upgrade IPs from stored vs current
            old_ips = firestore.get_list("node-ips")
            upgrade_ips = [ip for ip in config.node_ips if ip not in old_ips]
            add_cluster_nodes(config, firestore, upgrade_ips)

        if operation_flags["remove_nodes"]:
            logging.info("EXECUTING: Remove nodes operation")
            remove_cluster_nodes(config, firestore)

        # Update floating IPs for existing clusters
        maybe_update_floating_ips(config, qq_host, firestore)

    # Apply additional operations
    if operation_flags["increase_limit"]:
        logging.info("EXECUTING: Capacity limit increase")
        update_capacity_limit(config, firestore, qq_host)

    if operation_flags["add_buckets"]:
        logging.info("EXECUTING: Add storage buckets")
        add_object_buckets(config, firestore, qq_host)

    # Always update instance labels at the end
    update_instance_labels(config)


################################################################################
#                       MAIN ENTRY POINT                                       #
################################################################################


def provision(config: ProvisioningConfig, firestore: FirestoreManager) -> None:
    try:
        admin_password, out_quorum, in_quorum = initialize_and_validate(config, firestore)
        operation_flags = determine_cluster_operations(config, firestore, out_quorum, in_quorum, admin_password)
        execute_cluster_operations(config, firestore, admin_password, operation_flags)

        firestore.update_status("Shutting down provisioning instance")
        logging.info("GCP QProvisioner provisioning completed successfully")

    except Exception as e:
        firestore.update_status(f"ERROR: {str(e)}")
        raise


def main() -> None:
    """Main entry point for the provisioning script"""

    logging.basicConfig(
        filename="/var/log/qumulo.log",
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        filemode="a"
    )

    logging.info("Starting GCP QProvisioner provisioning")

    try:
        # Change to root directory for operations
        os.chdir("/root")

        # Create configuration from template variables
        config = create_provisioning_config()
        logging.info(f"Configuration loaded for cluster: {config.cluster_name}")
        logging.info(f"Project: {config.project}, Region: {config.region}")
        logging.info(f"Target node count: {config.target_node_count}")
        logging.info(f"Storage type: {config.cluster_persistent_storage_type}")
        logging.info(f"Replace cluster: {config.replace_cluster}")

        install_firestore_dependencies(config)
        firestore = FirestoreManager(config)

        provision(config, firestore)

        # Power off after successful provisioning in non-dev environments
        if not config.dev_environment:
            subprocess.run(["poweroff"], check=False)

    except Exception as e:
        logging.error(f"Provisioning failed: {str(e)}")
        raise


if __name__ == "__main__":
    main()
