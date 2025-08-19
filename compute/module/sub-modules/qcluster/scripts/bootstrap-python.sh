#!/bin/bash
# Bootstrap script to ensure Python 3 is available before running user-data.py
# This leverages the shared Python installation logic from python_installer.sh

set -euo pipefail

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - BOOTSTRAP: $*" | tee -a /var/log/user-data.log
}

# Main bootstrap logic
main() {
    log "=== Starting Python bootstrap process ==="

    # Ensure we're running as root
    if [ "$EUID" -ne 0 ]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi

    # Template variables (substituted by terraform)
    # shellcheck disable=SC2154
    GCS_BUCKET="${gcs_bucket_name}"
    # shellcheck disable=SC2154,SC2034
    FUNCTIONS_GCS_PREFIX="${functions_gcs_prefix}"
    # shellcheck disable=SC2154
    INSTALL_QUMULO_PACKAGE="${install_qumulo_package}"
    # shellcheck disable=SC2154
    QUMULO_PACKAGE_URL="${qumulo_package_url}"
    # shellcheck disable=SC2154
    TOTAL_DISK_COUNT="${total_disk_count}"

    # Change to root directory for operations
    cd /root

    # Download the required shared Python installation script from GCS
    PYTHON_INSTALLER="./python_installer.sh"
    log "Downloading Python installer from: gs://$GCS_BUCKET/$${FUNCTIONS_GCS_PREFIX}python_installer.sh"

    if ! gcloud storage cp "gs://$GCS_BUCKET/$${FUNCTIONS_GCS_PREFIX}python_installer.sh" "$PYTHON_INSTALLER"; then
        log "ERROR: Failed to download python_installer.sh from GCS"
        exit 1
    fi

    chmod +x "$PYTHON_INSTALLER"
    log "✓ Python installer downloaded successfully"

    # Download the main Python user-data script from GCS
    PYTHON_SCRIPT="./user-data.py"
    log "Downloading user-data script from: gs://$GCS_BUCKET/$${FUNCTIONS_GCS_PREFIX}user-data.py"

    if ! gcloud storage cp "gs://$GCS_BUCKET/$${FUNCTIONS_GCS_PREFIX}user-data.py" "$PYTHON_SCRIPT"; then
        log "ERROR: Failed to download user-data.py from GCS"
        exit 1
    fi

    chmod +x "$PYTHON_SCRIPT"
    log "✓ User-data script downloaded successfully"

    log "Sourcing Python installer from: $PYTHON_INSTALLER"
    # shellcheck disable=SC1090
    source "$PYTHON_INSTALLER"

    # Use the shared function to ensure Python 3 is available
    if ! ensure_python3; then
        log "ERROR: Failed to ensure Python 3 availability"
        exit 1
    fi

    log "✓ Python 3 bootstrap complete"

    # Execute the Python user-data script
    log "Executing user-data.py..."

    # Check if Python script exists
    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        log "ERROR: Python script not found at: $PYTHON_SCRIPT"
        exit 1
    fi

    # Execute the Python script with terraform template variables as arguments
    exec python3 "$PYTHON_SCRIPT" "$INSTALL_QUMULO_PACKAGE" "$QUMULO_PACKAGE_URL" "$TOTAL_DISK_COUNT" "$@"
}

# Execute main function
main "$@"
