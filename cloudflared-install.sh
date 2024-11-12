#!/bin/bash

set -e

# Function to print error messages to STDERR
error() {
    echo "ERROR: $*" >&2
}

# Detect the architecture
ARCH=$(uname -m)
echo "Detected architecture: ${ARCH}"

# Function to install curl based on the package manager
install_curl() {
    if ! command -v curl &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo "Installing curl using apt-get"
            sudo apt-get update || error "Failed to update package list"
            sudo apt-get install -y curl || error "Failed to install curl"
        elif command -v yum &> /dev/null; then
            echo "Installing curl using yum"
            sudo yum update -y || error "Failed to update package list"
            sudo yum install -y curl || error "Failed to install curl"
        else
            error "Unsupported package manager"
            exit 1
        fi
    else
        echo "curl is already installed"
    fi
}

# Function to install cloudflared on DEB-based systems
install_deb() {
    echo "Installing cloudflared on DEB-based system"
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb || error "Failed to download cloudflared DEB package"
    sudo apt-get install -y ./cloudflared-linux-amd64.deb || error "Failed to install cloudflared DEB package"
    rm cloudflared-linux-amd64.deb
}

# Function to install cloudflared on RPM-based systems
install_rpm() {
    echo "Installing cloudflared on RPM-based system"
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm || error "Failed to download cloudflared RPM package"
    sudo yum install -y ./cloudflared-linux-x86_64.rpm || error "Failed to install cloudflared RPM package"
    rm cloudflared-linux-x86_64.rpm
}

# Install curl if not already installed
install_curl

# Set the download URL based on the architecture
if [[ "${ARCH}" == "x86_64" ]]; then
    if [[ -f /etc/debian_version ]]; then
        install_deb
    elif [[ -f /etc/redhat-release ]]; then
        install_rpm
    else
        error "Unsupported Linux distribution for x86_64 architecture"
        exit 1
    fi
elif [[ "${ARCH}" == "aarch64" ]]; then
    echo "Installing cloudflared for aarch64 architecture"
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    curl -L "${URL}" -o cloudflared || error "Failed to download cloudflared"
    sudo mv cloudflared /usr/local/bin/ || error "Failed to move cloudflared to /usr/local/bin/"
    sudo chmod +x /usr/local/bin/cloudflared || error "Failed to make cloudflared executable"
elif [[ "${ARCH}" == "armv7l" ]]; then
    echo "Installing cloudflared for armv7l architecture"
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
    curl -L "${URL}" -o cloudflared || error "Failed to download cloudflared"
    sudo mv cloudflared /usr/local/bin/ || error "Failed to move cloudflared to /usr/local/bin/"
    sudo chmod +x /usr/local/bin/cloudflared || error "Failed to make cloudflared executable"
else
    error "Unsupported architecture: ${ARCH}"
    exit 1
fi

# Verify the installation
echo "Verifying cloudflared installation"
cloudflared -v || error "cloudflared verification failed"

# Configure cloudflared to run as a DNS over HTTPS proxy
echo "Configuring cloudflared to run as a DNS over HTTPS proxy"
sudo useradd -s /usr/sbin/nologin -r -M cloudflared || error "Failed to add cloudflared user"
sudo mkdir -p /etc/cloudflared || error "Failed to create /etc/cloudflared directory"
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-upstream:
 - https://1.1.1.1/dns-query
 - https://1.0.0.1/dns-query
EOF

# Create a systemd service for cloudflared
echo "Creating systemd service for cloudflared"
sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=network.target

[Service]
Type=simple
User=cloudflared
ExecStart=/usr/local/bin/cloudflared --config /etc/cloudflared/config.yml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the cloudflared service
echo "Enabling and starting the cloudflared service"
sudo systemctl enable cloudflared || error "Failed to enable cloudflared service"
sudo systemctl start cloudflared || error "Failed to start cloudflared service"

# Verify that the service is running
echo "Verifying that the cloudflared service is running"
sudo systemctl status cloudflared || error "cloudflared service is not running"