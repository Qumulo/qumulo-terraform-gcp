#!/bin/bash
# Shared Python Installation Functions
# Common Python installation logic for VM environments
# Can be sourced by other scripts that need Python 3

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "$ID $VERSION_ID"
    elif command -v lsb_release >/dev/null 2>&1; then
        lsb_release -si
    else
        echo "unknown"
    fi
}

# Function to check if Python 3 is available
check_python3() {
    if command -v python3 >/dev/null 2>&1; then
        local python_version
        python_version=$(python3 --version 2>&1)
        echo "Python 3 found: $python_version"
        return 0
    else
        echo "Python 3 not found"
        return 1
    fi
}

# Function to install Python based on OS
install_python() {
    local os_info
    os_info=$(detect_os)
    echo "Detected OS: $os_info"

    case "$os_info" in
        ubuntu*|debian*)
            echo "Installing Python on Ubuntu/Debian..."
            apt-get update -qq
            apt-get install -y python3 python3-pip curl
            ;;
        rocky*|rhel*|centos*|fedora*)
            echo "Installing Python on RHEL/Rocky/CentOS..."
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y python3 python3-pip curl
            else
                yum install -y python3 python3-pip curl
            fi
            ;;
        *)
            echo "WARNING: Unsupported OS detected: $os_info"
            echo "Attempting generic Python installation..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update -qq
                apt-get install -y python3 python3-pip curl
            elif command -v yum >/dev/null 2>&1; then
                yum install -y python3 python3-pip curl
            elif command -v dnf >/dev/null 2>&1; then
                dnf install -y python3 python3-pip curl
            else
                echo "ERROR: Cannot install Python - no supported package manager found"
                exit 1
            fi
            ;;
    esac
}

# Function to verify Python installation
verify_python() {
    echo "Verifying Python installation..."

    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 command not found after installation"
        return 1
    fi

    local python_version
    python_version=$(python3 --version 2>&1)
    echo "Python version: $python_version"

    # Check if it's Python 3.6+
    if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)" 2>/dev/null; then
        echo "ERROR: Python 3.6+ required, found: $python_version"
        return 1
    fi

    echo "✓ Python installation verified"
    return 0
}

# Function to verify standard library modules (commonly needed)
verify_stdlib_modules() {
    echo "Verifying Python standard library modules..."

    local modules=("json" "urllib.request" "urllib.error" "os" "sys" "subprocess" "logging" "time")

    for module in "${modules[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            echo "✓ Module '$module' available"
        else
            echo "✗ Module '$module' not available"
            return 1
        fi
    done

    echo "✓ All standard library modules verified"
    return 0
}

# Function to ensure Python 3 is ready (install if needed, verify)
ensure_python3() {
    echo "=== Ensuring Python 3 is available ==="

    if check_python3; then
        echo "Python 3 already available"
    else
        echo "Installing Python 3..."
        install_python
    fi

    if ! verify_python; then
        echo "ERROR: Python 3 verification failed"
        return 1
    fi

    if ! verify_stdlib_modules; then
        echo "ERROR: Python standard library verification failed"
        return 1
    fi

    echo "✓ Python 3 is ready for use"
    return 0
}