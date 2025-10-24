#!/usr/bin/env python3
"""
Qumulo Cluster Node Initialization Script

This script prepares cluster nodes for Qumulo Core installation with automatic
OS detection and appropriate configuration for:
- Ubuntu/Debian systems (apt/deb packages)
- RHEL/Rocky/CentOS systems (dnf/rpm packages)

Features:
- Automatic OS detection and package manager selection
- One-time execution control with flag files
- Network connectivity validation
- Package installation with retry logic
- OS-specific system configuration
- Qumulo Core package installation
- Block device monitoring
"""

import json
import logging
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error
from abc import ABC, abstractmethod
from pathlib import Path

# Configuration constants
FIRST_BOOT_FLAG = "/var/lib/first_boot_done"
LOG_FILE = "/var/log/user-data.log"
MAX_RETRIES = 5
RETRY_DELAY = 10
CONNECTIVITY_TIMEOUT = 30

class OSInfo:
    """Container for operating system information"""

    def __init__(self, os_id, version_id, package_manager, package_ext):
        self.os_id = os_id
        self.version_id = version_id
        self.package_manager = package_manager
        self.package_ext = package_ext
        self.is_debian_based = package_manager == "apt"
        self.is_rhel_based = package_manager in ["dnf", "yum"]


class BaseNodeInitializer(ABC):
    """Base class for Qumulo cluster node initialization"""

    def __init__(self, os_info):
        self.os_info = os_info
        self.setup_logging()
        self.logger = logging.getLogger(__name__)

    def setup_logging(self):
        """Configure logging to both file and console"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(LOG_FILE),
                logging.StreamHandler(sys.stdout)
            ]
        )

    def run_command(self, cmd, env=os.environ, check=True, timeout=60):
        """Execute a shell command with comprehensive error handling"""
        try:
            cmd_str = ' '.join(cmd) if isinstance(cmd, list) else cmd
            self.logger.info(f"Running command: {cmd_str}")

            if isinstance(cmd, str):
                cmd = cmd.split()

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=check,
                env=env
            )                

            if result.stdout:
                self.logger.debug(f"Command output: {result.stdout.strip()}")
            if result.stderr:
                self.logger.info(f"Additional output: {result.stderr.strip()}")

            return result

        except subprocess.CalledProcessError as e:
            self.logger.error(f"Command failed with return code {e.returncode}")
            self.logger.error(f"Stdout: {e.stdout}")
            self.logger.error(f"Stderr: {e.stderr}")
            if check:
                raise
            return e

        except subprocess.TimeoutExpired as e:
            self.logger.error(f"Command timed out after {timeout}s")
            if check:
                raise
            return e

        except Exception as e:
            self.logger.error(f"Unexpected error executing command: {e}")
            if check:
                raise
            return e

    def check_first_boot(self):
        """Check if this is the first boot execution"""
        if Path(FIRST_BOOT_FLAG).exists():
            self.logger.info("First boot commands already executed")
            return False
        return True

    def mark_first_boot_complete(self):
        """Create flag file to mark first boot as complete"""
        try:
            Path(FIRST_BOOT_FLAG).touch()
            self.logger.info("First boot marked as complete")
        except Exception as e:
            self.logger.error(f"Failed to create first boot flag: {e}")
            raise

    def check_connectivity(self):
        """Validate network connectivity to required services"""
        self.logger.info("Checking network connectivity...")

        # Test Google APIs connectivity
        self.logger.info("Testing Google APIs connectivity...")
        try:
            # Test Google APIs Discovery endpoint - returns proper HTTP 200
            with urllib.request.urlopen("https://www.googleapis.com/discovery/v1/apis", timeout=CONNECTIVITY_TIMEOUT) as response:
                if response.status == 200:
                    self.logger.info("✓ Google APIs reachable")
                else:
                    self.logger.warning(f"Unexpected Google APIs response: {response.status}")

        except Exception as e:
            self.logger.error(f"Google APIs unreachable: {e}")
            raise RuntimeError("Google APIs connectivity check failed")

        # Test internet connectivity
        self.logger.info("Testing internet connectivity...")
        try:
            with urllib.request.urlopen("https://google.com", timeout=CONNECTIVITY_TIMEOUT) as response:
                if response.status == 200:
                    self.logger.info("✓ Internet reachable")
                else:
                    self.logger.warning(f"Unexpected internet response: {response.status}")

        except Exception as e:
            self.logger.error(f"Internet unreachable: {e}")
            raise RuntimeError("Internet connectivity check failed")

    def verify_gcloud_cli(self):
        """Verify Google Cloud CLI is available and functional"""
        self.logger.info("Verifying Google Cloud CLI...")

        try:
            result = self.run_command(["gcloud", "--version"])
            self.logger.info("✓ GCP CLI available")
            self.logger.debug(f"gcloud version: {result.stdout.strip()}")
        except Exception as e:
            self.logger.error("GCP CLI not available!")
            raise RuntimeError("Google Cloud CLI is required but not available")

    def enable_frontend_interface_service(self):
        """
        Write out and enable a service that tags the frontend interface so qfsd can find it.

        This is important in the live-off-the-land networking mode,
        QUMULO_NETWORK_MANAGED_BY_HOST=true, because qfsd has to interact with
        host network interfaces and this is the way it knows which one to assign
        floating IPs.
        """
        self.logger.info("Setting up frontend interface tagging service...")

        def get_mac_address_from_metadata_service():
            try:
                request = urllib.request.Request("http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/mac")
                request.add_header("Metadata-Flavor", "Google")
                with urllib.request.urlopen(request) as f:
                    return f.read().decode('utf-8')
            except Exception as e:
                self.logger.error(f"Failed to get MAC address from metadata service: {e}")
                raise RuntimeError("Failed to get MAC address from metadata service")

        try:
            mac_address = get_mac_address_from_metadata_service()
            link_content = f"""
[Match]
MACAddress={mac_address}

[Link]
AlternativeName=qumulo-frontend1
"""

            systemd_network = Path("/etc/systemd/network")
            systemd_network.mkdir(parents=True, exist_ok=True)
            link_unit = systemd_network / "05-qumulo-frontend-link-altname.link"
            link_unit.write_text(link_content)
            link_unit.chmod(0o644)

            # Trigger a udev "add" event to force the altname to be aplied
            self.run_command(["udevadm", "trigger", "--action=add"])
            self.logger.info("✓ Frontend interface tagging service enabled")

        except Exception as e:
            self.logger.error(f"Failed to setup frontend interface service: {e}")
            raise RuntimeError("Failed to enable frontend interface tagging service")

    def count_block_devices(self):
        """Count block devices of type 'disk' using lsblk JSON output"""
        try:
            result = self.run_command(["lsblk", "-J"])
            lsblk_data = json.loads(result.stdout)

            disk_count = len([
                device for device in lsblk_data.get("blockdevices", [])
                if device.get("type") == "disk"
            ])

            self.logger.debug(f"Found {disk_count} block devices")
            return disk_count

        except Exception as e:
            self.logger.error(f"Failed to count block devices: {e}")
            return 0

    def wait_for_block_devices(self, expected_count):
        """Wait for all expected block devices to appear"""
        self.logger.info(f"Waiting for {expected_count} block devices...")

        while True:
            current_count = self.count_block_devices()
            if current_count >= expected_count:
                self.logger.info(f"✓ All {expected_count} block devices found")
                break

            self.logger.info(f"Waiting for block devices: found {current_count}, expecting {expected_count}")
            time.sleep(1)

    def download_qumulo_package(self, package_url):
        """Download Qumulo Core package from GCS or HTTP URL"""
        package_file = f"./qumulo-core.{self.os_info.package_ext}"

        self.logger.info(f"Downloading Qumulo package from: {package_url}")

        try:
            # Use longer timeout for large package downloads (15 minutes)
            download_timeout = 900

            if package_url.startswith("gs://"):
                self.run_command(["gcloud", "storage", "cp", package_url, package_file], timeout=download_timeout)
            else:
                # Add retry options for HTTP downloads
                self.run_command(["curl", package_url, "-L", "-o", package_file, "--silent", "--show-error", "--retry", "3", "--retry-delay", "5"], timeout=download_timeout)

            self.logger.info("✓ Qumulo package downloaded")
            return package_file

        except Exception as e:
            self.logger.error(f"Failed to download Qumulo package: {e}")
            raise

    def install_qumulo_core(self, package_url, total_disk_count):
        """Install Qumulo Core package"""
        self.logger.info("Installing Qumulo Core...")

        # Set required environment variable
        os.environ["QUMULO_NETWORK_MANAGED_BY_HOST"] = "true"
        self.logger.info("✓ QUMULO_NETWORK_MANAGED_BY_HOST set to true")

        # Download package
        package_file = self.download_qumulo_package(package_url)

        # Wait for all expected disks
        self.wait_for_block_devices(total_disk_count)

        # Install using OS-specific method
        self.install_package_file(package_file)
        self.logger.info("✓ Qumulo Core installed successfully")

    def run_initialization(self, install_qumulo_package, qumulo_package_url=None, total_disk_count=None):
        """Execute the complete node initialization process"""
        try:
            self.logger.info("=== Starting Qumulo cluster node initialization ===")
            self.logger.info(f"OS: {self.os_info.os_id} {self.os_info.version_id}")
            self.logger.info(f"Package manager: {self.os_info.package_manager}")

            # Check if first boot
            if not self.check_first_boot():
                return

            # Change to root directory
            os.chdir("/root")
            self.logger.info("Working directory: /root")

            # Execute initialization steps
            self.check_connectivity()
            self.uninstall_undesired_packages()
            self.install_required_packages()
            self.configure_system_services()
            self.verify_gcloud_cli()

            # Enable frontend interface tagging service for floating IPs support
            self.enable_frontend_interface_service()

            # Install Qumulo Core if requested
            if install_qumulo_package == "true":
                self.logger.info("Installing Qumulo Core...")

                # Validate required parameters
                if not qumulo_package_url or total_disk_count is None:
                    error_msg = f"Missing required parameters: qumulo_package_url='{qumulo_package_url}', total_disk_count='{total_disk_count}'"
                    self.logger.error(f"✗ {error_msg}")
                    raise ValueError(f"qumulo_package_url and total_disk_count required when install_qumulo_package=true. {error_msg}")

                self.install_qumulo_core(qumulo_package_url, int(total_disk_count))
            else:
                self.logger.info(f"Skipping Qumulo package installation (install_qumulo_package='{install_qumulo_package}')")
                if install_qumulo_package.startswith("${"):
                    self.logger.error("WARNING: Template variable was not substituted by terraform!")

            # Mark completion
            self.mark_first_boot_complete()
            self.logger.info("=== Qumulo cluster node initialization completed successfully ===")

        except Exception as e:
            self.logger.error(f"Initialization failed: {e}")
            raise

    # Abstract methods that must be implemented by subclasses
    @abstractmethod
    def install_package(self, package_name):
        """Install a package using OS-specific package manager"""
        pass

    @abstractmethod
    def update_package_list(self):
        """Update package list using OS-specific method"""
        pass

    @abstractmethod
    def install_required_packages(self):
        """Install OS-specific required packages"""
        pass

    @abstractmethod
    def uninstall_undesired_packages(self):
        """Uninstall OS-specific undesired packages"""
        pass

    @abstractmethod
    def configure_system_services(self):
        """Configure OS-specific system services"""
        pass

    @abstractmethod
    def install_package_file(self, package_file):
        """Install a package file using OS-specific method"""
        pass


class DebianNodeInitializer(BaseNodeInitializer):
    """Debian/Ubuntu-specific node initializer"""

    def install_package(self, package_name):
        """Install a package via apt with retry logic"""
        self.logger.info(f"Installing package: {package_name}")

        # Check if already installed
        check_cmd = ["dpkg", "-s", package_name]
        result = self.run_command(check_cmd, check=False)
        if result.returncode == 0:
            self.logger.info(f"✓ {package_name} already installed")
            return

        env_mod = os.environ.copy()
        env_mod['DEBIAN_FRONTEND'] = 'noninteractive'

        # Install with retry logic
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                self.logger.info(f"Installing {package_name} (attempt {attempt}/{MAX_RETRIES})")         
                self.run_command(["apt-get", "install", "-y", package_name], env=env_mod, timeout=300)
                self.logger.info(f"✓ {package_name} installed successfully")
                return

            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                if attempt == MAX_RETRIES:
                    self.logger.error(f"Failed to install {package_name} after {MAX_RETRIES} attempts")
                    raise RuntimeError(f"Package installation failed: {package_name}")

                self.logger.warning(f"Install attempt {attempt} failed, retrying in {RETRY_DELAY}s...")
                time.sleep(RETRY_DELAY)

    def uninstall_package(self, package_name):
        """Uninstall a package via apt with retry logic"""
        self.logger.info(f"Uninstalling package: {package_name}")

        # Check if installed
        check_cmd = ["dpkg", "-s", package_name]
        result = self.run_command(check_cmd, check=False)
        if result.returncode != 0:
            self.logger.info(f"✓ {package_name} wasn't installed")
            return

        # Uninstall with retry logic
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                self.logger.info(f"Uninstalling {package_name} (attempt {attempt}/{MAX_RETRIES})")
                self.run_command(["apt-get", "remove", "-y", package_name], timeout=300)
                self.logger.info(f"✓ {package_name} uninstalled successfully")
                return

            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                if attempt == MAX_RETRIES:
                    self.logger.error(f"Failed to uninstall {package_name} after {MAX_RETRIES} attempts")
                    raise RuntimeError(f"Package removal failed: {package_name}")

                self.logger.warning(f"Uninstall attempt {attempt} failed, retrying in {RETRY_DELAY}s...")
                time.sleep(RETRY_DELAY)

    def update_package_list(self):
        """Update apt package list"""
        self.logger.info("Updating package list...")
        self.run_command(["apt-get", "update"], timeout=300)
        self.logger.info("✓ Package list updated")

    def get_kernel_release(self):
        """Get kernel release for linux-tools installation"""
        try:
            result = self.run_command(["uname", "-r"])
            kernel_release = result.stdout.strip()
            self.logger.info(f"Kernel release: {kernel_release}")
            return kernel_release
        except Exception as e:
            self.logger.error(f"Failed to get kernel release: {e}")
            raise

    def install_required_packages(self):
        """Install Debian/Ubuntu required packages"""
        self.logger.info("Installing required packages for Debian/Ubuntu...")

        self.update_package_list()

        kernel_release = self.get_kernel_release()
        packages = [
            "jq",
            "unzip",
            "iperf3",
            "linux-tools-common",
            f"linux-tools-{kernel_release}",
            "systemd-container"
        ]

        for package in packages:
            self.install_package(package)

        self.logger.info("✓ All required packages installed")

    def uninstall_undesired_packages(self):
        """Uninstall Debian/Ubuntu undesired packages"""
        self.logger.info("Uninstalling undesired packages for Debian/Ubuntu...")

        self.update_package_list()

        packages = [
            # We run chrony inside the container - there's no need to run a timesync service in
            # the host.
            'chrony',
            # ubuntu-advantage-tools enables Ubuntu support features on cloud images. Not only do
            # we not need support features, these tools issue incorrectly formed requests to
            # instance metadata that are missing the Metadata-Flavor header, causing
            # crashes to appear in /var/crash if left enabled.
            'ubuntu-advantage-tools',
        ]

        for package in packages:
            self.uninstall_package(package)

        self.logger.info("✓ All undesired packages uninstalled")

    def configure_system_services(self):
        """Configure system services for Debian/Ubuntu"""
        self.logger.info("Configuring system services for Debian/Ubuntu...")

        # Disable systemd-timesyncd (needed on Debian, not always Ubuntu)
        try:
            self.run_command(["systemctl", "stop", "systemd-timesyncd.service"], check=False)
            self.run_command(["systemctl", "mask", "--now", "systemd-timesyncd"])
            self.logger.info("✓ systemd-timesyncd disabled")
        except Exception as e:
            self.logger.warning(f"systemd-timesyncd configuration: {e}")

        # Disable apparmor from preventing chrony execution in containers
        try:
            self.run_command(["ln", "-s", "/etc/apparmor.d/usr.sbin.chronyd", "/etc/apparmor.d/disable/"], check=False)
            self.run_command(["apparmor_parser", "-R", "/etc/apparmor.d/usr.sbin.chronyd"], check=False)
            self.logger.info("✓ apparmor chronyd profile removed")
        except Exception as e:
            raise RuntimeError('Failed to disable apparmor from preventing chrony execution in containers') from e

        # Disable ubuntu-advantage to prevent it from generating core files
        try:
            self.run_command(["systemctl", "stop", "ubuntu-advantage.service"], check=False)
            self.run_command(["systemctl", "mask", "--now", "ubuntu-advantage"])
            self.logger.info("✓ ubuntu-advantage disabled")
        except Exception as e:
            raise RuntimeError('Failed to disable ubuntu-advantage') from e

    def install_package_file(self, package_file):
        """Install a .deb package file"""
        self.logger.info("Installing Qumulo Core package...")
        # Use longer timeout for package installation (10 minutes)
        self.run_command(["apt", "install", "-y", package_file], timeout=600)


class RHELNodeInitializer(BaseNodeInitializer):
    """RHEL/Rocky/CentOS-specific node initializer"""

    def install_package(self, package_name):
        """Install a package via dnf/yum with retry logic"""
        self.logger.info(f"Installing package: {package_name}")

        # Check if already installed
        check_cmd = ["rpm", "-q", package_name]
        result = self.run_command(check_cmd, check=False)
        if result.returncode == 0:
            self.logger.info(f"✓ {package_name} already installed")
            return

        # Install with retry logic
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                self.logger.info(f"Installing {package_name} (attempt {attempt}/{MAX_RETRIES})")
                self.run_command([self.os_info.package_manager, "install", "-y", package_name], timeout=300)
                self.logger.info(f"✓ {package_name} installed successfully")
                return

            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                if attempt == MAX_RETRIES:
                    self.logger.error(f"Failed to install {package_name} after {MAX_RETRIES} attempts")
                    raise RuntimeError(f"Package installation failed: {package_name}")

                self.logger.warning(f"Install attempt {attempt} failed, retrying in {RETRY_DELAY}s...")
                time.sleep(RETRY_DELAY)

    def update_package_list(self):
        """Update package list (dnf handles this automatically)"""
        self.logger.info("Package list management handled automatically by dnf")

    def setup_repositories(self):
        """Setup required repositories for RHEL/Rocky systems"""
        self.logger.info("Setting up RHEL/Rocky repositories...")

        # Check if this is RHEL (not Rocky/CentOS)
        try:
            with open('/etc/os-release', 'r') as f:
                os_release_content = f.read()

            if 'ID="rhel"' not in os_release_content:
                # Enable CRB repository for Rocky/CentOS
                self.run_command([self.os_info.package_manager, "-y", "config-manager", "--set-enabled", "crb"], timeout=300)
                self.install_package("epel-release")
                self.run_command(["crb", "enable"], timeout=300)
                self.logger.info("✓ CRB and EPEL repositories enabled")

        except Exception as e:
            self.logger.warning(f"Repository setup: {e}")

    def install_required_packages(self):
        """Install RHEL/Rocky required packages"""
        self.logger.info("Installing required packages for RHEL/Rocky...")

        self.setup_repositories()

        packages = [
            "jq",
            "iperf3",
            "systemd-container",
            "systemd-resolved",
            "unzip"
        ]

        for package in packages:
            self.install_package(package)

        self.logger.info("✓ All required packages installed")

    def uninstall_undesired_packages(self):
        """Uninstall RHEL/Rocky undesired packages"""
        pass

    def create_cloud_init_config(self):
        """Create cloud-init configuration files"""
        try:
            cloud_cfg_dir = Path("/etc/cloud/cloud.cfg.d")
            cloud_cfg_dir.mkdir(parents=True, exist_ok=True)

            cloud_cfg_content = """disable_network_activation: true
network:
    config: disabled
"""
            config_file = cloud_cfg_dir / "99-disable-network-config.cfg"
            config_file.write_text(cloud_cfg_content)
            self.logger.info("✓ Cloud-init network config disabled")

        except Exception as e:
            self.logger.warning(f"Cloud-init configuration: {e}")

    def configure_sysctl_settings(self):
        """Configure sysctl settings for Qumulo"""
        try:
            sysctl_dir = Path("/etc/sysctl.d")
            sysctl_dir.mkdir(parents=True, exist_ok=True)

            sysctl_content = """# Enable io_uring for all processes
kernel.io_uring_disabled = 0
"""
            sysctl_file = sysctl_dir / "99-rocky9.conf"
            sysctl_file.write_text(sysctl_content)

            # Apply immediately
            self.run_command(["sysctl", "-w", "kernel.io_uring_disabled=0"])
            self.logger.info("✓ io_uring enabled")

        except Exception as e:
            self.logger.warning(f"sysctl configuration: {e}")

    def configure_selinux(self):
        """Configure SELinux for Qumulo compatibility"""
        try:
            selinux_config = Path("/etc/selinux/config")
            if not selinux_config.exists():
                return

            # Read current configuration
            content = selinux_config.read_text()

            # Set to permissive mode
            content = content.replace("SELINUX=enforcing", "SELINUX=permissive")
            content = content.replace("SELINUX=disabled", "SELINUX=permissive")

            selinux_config.write_text(content)

            # Apply immediately
            self.run_command(["setenforce", "Permissive"], check=False)
            self.logger.info("✓ SELinux set to permissive mode")

        except Exception as e:
            self.logger.warning(f"SELinux configuration: {e}")

    def remove_conflicting_services(self):
        """Remove and disable services that conflict with Qumulo"""
        # Remove NetworkManager package
        try:
            self.run_command([self.os_info.package_manager, "-y", "remove", "NetworkManager"], check=False, timeout=300)
            self.logger.info("✓ NetworkManager package removed")
        except Exception as e:
            self.logger.warning(f"NetworkManager removal: {e}")

        # Disable conflicting services
        services_to_disable = [
            ("NetworkManager", "NetworkManager.service"),
            ("systemd-timesyncd", "systemd-timesyncd.service"),
            ("rpcbind", "rpcbind.service"),
            ("rpcbind.socket", "rpcbind.socket"),
            ("firewalld", "firewalld.service")
        ]

        for service_name, service_unit in services_to_disable:
            try:
                self.run_command(["systemctl", "stop", service_unit], check=False)
                self.run_command(["systemctl", "mask", "--now", service_unit], check=False)
                self.logger.info(f"✓ {service_name} disabled")
            except Exception as e:
                self.logger.warning(f"{service_name} configuration: {e}")

    def apply_system_settings(self):
        """Apply all system configuration changes"""
        try:
            self.run_command(["sysctl", "--system"])
            self.logger.info("✓ System settings applied")
        except Exception as e:
            self.logger.warning(f"System settings application: {e}")

    def configure_system_services(self):
        """Configure system services for RHEL/Rocky"""
        self.logger.info("Configuring system services for RHEL/Rocky...")

        self.create_cloud_init_config()
        self.configure_sysctl_settings()
        self.configure_selinux()
        self.remove_conflicting_services()
        self.apply_system_settings()

    def install_package_file(self, package_file):
        """Install an .rpm package file"""
        self.logger.info("Installing Qumulo Core package...")
        # Use longer timeout for package installation (10 minutes)
        self.run_command([self.os_info.package_manager, "install", "-y", package_file], timeout=600)


class OSDetector:
    """Utility class for operating system detection"""

    @staticmethod
    def command_exists(command):
        """Check if a command exists in PATH"""
        try:
            subprocess.run(["which", command], capture_output=True, check=True)
            return True
        except subprocess.CalledProcessError:
            return False

    @classmethod
    def detect_os(cls):
        """Detect operating system and return OSInfo object"""
        try:
            # Read /etc/os-release for system information
            with open('/etc/os-release', 'r') as f:
                os_release = {}
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        os_release[key] = value.strip('"')

            os_id = os_release.get('ID', '').lower()
            version_id = os_release.get('VERSION_ID', '')

            # Determine package manager and extension based on OS
            if os_id in ['ubuntu', 'debian']:
                package_manager = "apt"
                package_ext = "deb"
            elif os_id in ['rhel', 'rocky', 'centos', 'fedora']:
                package_manager = "dnf"
                package_ext = "rpm"
            else:
                # Fallback detection by available package managers
                if cls.command_exists("apt-get"):
                    package_manager = "apt"
                    package_ext = "deb"
                elif cls.command_exists("dnf"):
                    package_manager = "dnf"
                    package_ext = "rpm"
                elif cls.command_exists("yum"):
                    package_manager = "yum"
                    package_ext = "rpm"
                else:
                    raise RuntimeError(f"Unsupported operating system: {os_id}")

            return OSInfo(os_id, version_id, package_manager, package_ext)

        except Exception as e:
            raise RuntimeError(f"Failed to detect operating system: {e}")


class NodeInitializerFactory:
    """Factory class for creating appropriate node initializers"""

    @staticmethod
    def create_initializer(os_info):
        """Create appropriate initializer based on OS information"""
        if os_info.is_debian_based:
            return DebianNodeInitializer(os_info)
        elif os_info.is_rhel_based:
            return RHELNodeInitializer(os_info)
        else:
            raise RuntimeError(f"Unsupported package manager: {os_info.package_manager}")


def main():
    """Main entry point for the initialization script"""
    # Set up early logging before anything else
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - USER-DATA - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler(sys.stdout)
        ]
    )
    logger = logging.getLogger(__name__)

    logger.info("=== Qumulo user-data.py script starting ===")

    # Parse command line arguments (passed from bootstrap script)
    if len(sys.argv) < 4:
        logger.error("ERROR: Missing required arguments")
        logger.error("Usage: user-data.py <install_qumulo_package> <qumulo_package_url> <total_disk_count>")
        logger.error(f"Received {len(sys.argv)} arguments: {sys.argv}")
        sys.exit(1)

    install_qumulo_package = sys.argv[1]
    qumulo_package_url = sys.argv[2]
    total_disk_count = sys.argv[3]

    try:
        # Detect operating system
        os_info = OSDetector.detect_os()
        logger.info(f"OS detected: {os_info.os_id} {os_info.version_id} ({os_info.package_manager})")

        # Create appropriate initializer
        initializer = NodeInitializerFactory.create_initializer(os_info)

        # Run initialization process
        initializer.run_initialization(
            install_qumulo_package=install_qumulo_package,
            qumulo_package_url=qumulo_package_url if install_qumulo_package == "true" else None,
            total_disk_count=total_disk_count if install_qumulo_package == "true" else None
        )

    except KeyboardInterrupt:
        logger.error("Initialization interrupted by user")
        sys.exit(1)

    except Exception as e:
        logger.error(f"Initialization failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
