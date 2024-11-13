#!/usr/bin/env bash

set -e

# Detect the architecture
ARCH=$(uname -m)
echo "Detected architecture: ${ARCH}"

# Default port
PORT=5053

# Array of DNS over HTTPS upstream servers
DNS_UPSTREAM_SERVERS=(
    "https://doh.la.ahadns.net/dns-query"
    "https://dns.digitale-gesellschaft.ch/dns-query"
)

# Function to print error messages to STDERR and abort the script
error() {
    echo "ERROR: $*" >&2
    exit 1
}

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --help       Show this help message and exit"
    echo "  --uninstall  Uninstall cloudflared and remove all files created by the script"
    echo "  --port PORT  Specify a custom port for the DNS over HTTPS proxy (default: 5053)"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help) show_help; exit 0 ;;
            --uninstall) uninstall_cloudflared; exit 0 ;;
            --port) PORT="$2"; shift ;;
            *) error "Unknown option: $1";;
        esac
        shift
    done
}

# Function to install curl based on the package manager
install_curl() {
    if ! command -v curl &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo "Installing curl using apt-get"
            apt-get update || error "Failed to update package list"
            apt-get install -y curl || error "Failed to install curl"
        elif command -v yum &> /dev/null; then
            echo "Installing curl using yum"
            yum update -y || error "Failed to update package list"
            yum install -y curl || error "Failed to install curl"
        else
            error "Unsupported package manager"
        fi
    else
        echo "curl is already installed"
    fi
}

# Function to install cloudflared on DEB-based systems
install_deb() {
    echo "Installing cloudflared on DEB-based system"
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb || error "Failed to download cloudflared DEB package"
    apt-get install -y ./cloudflared-linux-amd64.deb || error "Failed to install cloudflared DEB package"
    rm cloudflared-linux-amd64.deb
}

# Function to install cloudflared on RPM-based systems
install_rpm() {
    echo "Installing cloudflared on RPM-based system"
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm || error "Failed to download cloudflared RPM package"
    yum install -y ./cloudflared-linux-x86_64.rpm || error "Failed to install cloudflared RPM package"
    rm cloudflared-linux-x86_64.rpm
}

# Function to download cloudflared based on the architecture
download_cloudflared() {
    if [[ "${ARCH}" == "x86_64" ]]; then
        if [[ -f /etc/debian_version ]]; then
            install_deb
        elif [[ -f /etc/redhat-release ]]; then
            install_rpm
        else
            error "Unsupported Linux distribution for x86_64 architecture"
        fi
    elif [[ "${ARCH}" == "aarch64" ]]; then
        echo "Installing cloudflared for aarch64 architecture"
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
        curl -L "${URL}" -o cloudflared || error "Failed to download cloudflared"
        mv cloudflared /usr/local/bin/ || error "Failed to move cloudflared to /usr/local/bin/"
        chmod +x /usr/local/bin/cloudflared || error "Failed to make cloudflared executable"
    elif [[ "${ARCH}" == armv* ]]; then
        echo "Installing cloudflared for ARM architecture"
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
        curl -L "${URL}" -o cloudflared || error "Failed to download cloudflared"
        mv cloudflared /usr/local/bin/ || error "Failed to move cloudflared to /usr/local/bin/"
        chmod +x /usr/local/bin/cloudflared || error "Failed to make cloudflared executable"
    else
        error "Unsupported architecture: ${ARCH}"
    fi
}

# Function to configure cloudflared
configure_cloudflared() {
    echo "Configuring cloudflared to run as a DNS over HTTPS proxy"
    if ! id -u cloudflared &>/dev/null; then
        useradd -s /usr/sbin/nologin -r -M cloudflared || error "Failed to add cloudflared user"
    else
        echo "User cloudflared already exists"
    fi

    if [[ ! -d /opt/cloudflared ]]; then
        mkdir -p /opt/cloudflared || error "Failed to create /opt/cloudflared directory"
    else
        echo "/opt/cloudflared directory already exists"
    fi

    if [[ -f /opt/cloudflared/config.yml ]]; then
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        cp /opt/cloudflared/config.yml "/opt/cloudflared/config.yml.bak.${TIMESTAMP}" || error "Failed to create backup of existing config file"
        echo "Backup of existing config file created with timestamp ${TIMESTAMP}"
    fi

    {
        echo "proxy-dns: true"
        echo "proxy-dns-port: ${PORT}"
        echo "proxy-dns-upstream:"
        for server in "${DNS_UPSTREAM_SERVERS[@]}"; do
            echo " - ${server}"
        done
    } > /opt/cloudflared/config.yml
}

# Function to create a systemd service for cloudflared
create_systemd_service() {
    echo "Creating systemd service for cloudflared"
    tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=network.target

[Service]
Type=simple
User=cloudflared
ExecStart=/usr/local/bin/cloudflared --config /opt/cloudflared/config.yml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

# Function to enable and start the cloudflared service
enable_and_start_service() {
    echo "Enabling and starting the cloudflared service"
    systemctl enable cloudflared || error "Failed to enable cloudflared service"
    
    if systemctl is-active --quiet cloudflared; then
        echo "cloudflared service is already running, restarting it"
        systemctl restart cloudflared || error "Failed to restart cloudflared service"
    else
        echo "Starting cloudflared service"
        systemctl start cloudflared || error "Failed to start cloudflared service"
    fi
    
    echo "Verifying that the cloudflared service is running"
    systemctl status cloudflared || error "cloudflared service is not running"
}

# Function to create a system cron job for updating cloudflared
create_cron_job() {
    CRON_JOB="0 0 * * * root wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH} && chmod +x /usr/local/bin/cloudflared && systemctl restart cloudflared"
    echo "${CRON_JOB}" | tee /etc/cron.d/cloudflared-update > /dev/null || error "Failed to create system cron job"
    echo "System cron job for updating cloudflared created"
}

# Function to uninstall cloudflared and remove all files created by the script
uninstall_cloudflared() {
    echo "Stopping cloudflared service"
    systemctl stop cloudflared || error "Failed to stop cloudflared service"
    echo "Disabling cloudflared service"
    systemctl disable cloudflared || error "Failed to disable cloudflared service"
    echo "Removing cloudflared systemd service file"
    rm /etc/systemd/system/cloudflared.service || error "Failed to remove cloudflared systemd service file"
    echo "Removing /opt/cloudflared directory"
    rm -rf /opt/cloudflared || error "Failed to remove /opt/cloudflared directory"
    echo "Removing cloudflared binary"
    rm /usr/local/bin/cloudflared || error "Failed to remove cloudflared binary"
    echo "Removing cloudflared cron job"
    rm /etc/cron.d/cloudflared-update || error "Failed to remove cloudflared cron job"
    echo "Deleting cloudflared user"
    userdel cloudflared || error "Failed to delete cloudflared user"
    
    if [[ -f /etc/debian_version ]]; then
        echo "Uninstalling cloudflared package on DEB-based system"
        apt-get remove -y cloudflared || error "Failed to uninstall cloudflared package"
    elif [[ -f /etc/redhat-release ]]; then
        echo "Uninstalling cloudflared package on RPM-based system"
        yum remove -y cloudflared || error "Failed to uninstall cloudflared package"
    fi
    
    echo "Reloading systemd daemon"
    systemctl daemon-reload || error "Failed to reload systemd daemon"
    echo "cloudflared uninstalled successfully"
}

# Parse command line arguments
parse_arguments "$@"

# Install curl if not already installed
install_curl

# Download cloudflared
if ! command -v cloudflared &> /dev/null; then
    download_cloudflared
    # Verify the installation
    echo "Verifying cloudflared installation"
    cloudflared -v || error "cloudflared verification failed"
else
    echo "cloudflared is already installed"
fi

# Configure cloudflared
configure_cloudflared

# Create a systemd service
create_systemd_service

# Enable and start the cloudflared service
enable_and_start_service

# Create a cron job for updating cloudflared
create_cron_job