#!/bin/bash

# CNQ VM Dependency Installation Script
# Install Python and verify all required dependencies for Firestore operations
# Designed for VM environments with comprehensive OS support and verification

# Argument handling
gcs_bucket="${1:-}"
functions_gcs_prefix="${2:-}"

if [[ -z "$gcs_bucket" ]]; then
    echo "ERROR: GCS bucket name required as first argument"
    exit 1
fi

if [[ -z "$functions_gcs_prefix" ]]; then
    echo "ERROR: Functions GCS prefix required as second argument"
    exit 1
fi

echo "=== CNQ VM Dependency Installation ==="
echo "Bucket: $gcs_bucket"
echo "Prefix: $functions_gcs_prefix"
echo "========================================="

# Source shared Python installation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/python_installer.sh"

# Note: verify_python and verify_stdlib_modules are now provided by python_installer.sh

# Function to verify additional standard library modules (specific to firestore operations)
verify_firestore_stdlib_modules() {
    echo "Verifying Python standard library modules..."

    local required_modules=(
        "json"
        "subprocess"
        "sys"
        "urllib.request"
        "urllib.parse"
        "urllib.error"
        "datetime"
        "time"
    )

    local missing_modules=()

    for module in "${required_modules[@]}"; do
        if ! python3 -c "import $module" 2>/dev/null; then
            missing_modules+=("$module")
        fi
    done

    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        echo "ERROR: Missing required Python modules:"
        printf "  - %s\n" "${missing_modules[@]}"
        return 1
    fi

    echo "✓ All required Python modules available"
    return 0
}

# Function to verify gcloud CLI
verify_gcloud() {
    echo "Verifying gcloud CLI..."

    if ! command -v gcloud >/dev/null 2>&1; then
        echo "ERROR: gcloud CLI not found"
        echo "This script requires gcloud to be pre-installed on the VM"
        return 1
    fi

    local gcloud_version
    gcloud_version=$(gcloud version --format="value(Google Cloud SDK)" 2>/dev/null)
    echo "gcloud version: $gcloud_version"

    # Test authentication
    if ! gcloud auth print-access-token --quiet >/dev/null 2>&1; then
        echo "ERROR: gcloud authentication failed"
        echo "VM must have appropriate service account permissions"
        return 1
    fi

    echo "✓ gcloud CLI verified and authenticated"
    return 0
}

# Function to verify network connectivity
verify_network() {
    echo "Verifying network connectivity..."

    # Test basic connectivity
    if ! curl -s --connect-timeout 10 https://google.com >/dev/null; then
        echo "ERROR: No internet connectivity"
        return 1
    fi

    # Test Firestore API endpoint
    if ! curl -s --connect-timeout 10 https://firestore.googleapis.com >/dev/null; then
        echo "ERROR: Cannot reach Firestore API"
        echo "Check firewall rules and VPC configuration"
        return 1
    fi

    echo "✓ Network connectivity verified"
    return 0
}

# Function to test Python Firestore script
test_firestore_script() {
    echo "Testing Python Firestore script..."

    if [[ ! -f "firestore_vm.py" ]]; then
        echo "ERROR: firestore_vm.py not found"
        return 1
    fi

    # Test script syntax
    if ! python3 -m py_compile firestore_vm.py 2>/dev/null; then
        echo "ERROR: firestore_vm.py has syntax errors"
        return 1
    fi

    # Test basic script execution (help text)
    if ! python3 firestore_vm.py 2>&1 | grep -q "Usage:"; then
        echo "ERROR: firestore_vm.py not executing properly"
        return 1
    fi

    echo "✓ Python Firestore script verified"
    return 0
}

# Main installation and verification flow
main() {
    echo "Starting CNQ VM dependency installation..."

    # Use shared function to ensure Python 3 is ready (install if needed, verify)
    ensure_python3 || exit 1

    # Run additional firestore-specific verifications
    verify_firestore_stdlib_modules || exit 1
    verify_gcloud || exit 1
    verify_network || exit 1
    test_firestore_script || exit 1

    echo "========================================="
    echo "✓ All dependencies verified successfully"
    echo "✓ CNQ VM ready for Python Firestore operations"
    echo "========================================="
}

# Execute main function
main "$@"