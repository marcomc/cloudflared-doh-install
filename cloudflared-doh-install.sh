#!/usr/bin/env bash

set -e

# Function to print error messages to STDERR and abort the script
error() {
    echo "ERROR: $*" >&2
    exit 1
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
        sudo mv cloudflared /usr/local/bin/ || error "Failed to move cloudflared to /usr/local/bin/"
        sudo chmod +x /usr/local/bin/cloudflared || error "Failed to make cloudflared executable"
    elif [[ "${ARCH}" == armv* ]]; then
        echo "Installing cloudflared for ARM architecture"
        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
        curl -L "${URL}" -o cloudflared || error "Failed to download cloudflared"
        sudo mv cloudflared /usr/local/bin/ || error "Failed to move cloudflared to /usr/local/bin/"
        sudo chmod +x /usr/local/bin/cloudflared || error "Failed to make cloudflared executable"
    else
        error "Unsupported architecture: ${ARCH}"
    fi
}

# Function to configure cloudflared
configure_cloudflared() {
    echo "Configuring cloudflared to run as a DNS over HTTPS proxy"
    if ! id -u cloudflared &>/dev/null; then
        sudo useradd -s /usr/sbin/nologin -r -M cloudflared || error "Failed to add cloudflared user"
    else
        echo "User cloudflared already exists"
    fi

    if [ ! -d /etc/cloudflared ]; then
        sudo mkdir -p /etc/cloudflared || error "Failed to create /etc/cloudflared directory"
    else
        echo "/etc/cloudflared directory already exists"
    fi
    
    if [ -f /etc/cloudflared/config.yml ]; then
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        sudo cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml.bak.${TIMESTAMP} || error "Failed to create backup of existing config file"
        echo "Backup of existing config file created with timestamp ${TIMESTAMP}"
    fi

    sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-upstream:
#  - https://1.1.1.1/dns-query
#  - https://1.0.0.1/dns-query
# "doh.la.ahadns.net" is a public DNS over HTTPS server operated by AhaDNS
# A zero logging DNS with support for DNS-over-HTTPS (DoH) & DNS-over-TLS (DoT).
# Blocks ads, malware, trackers, viruses, ransomware, telemetry and more.
# No persistent logs. DNSSEC. Hosted in Amsterdam, Netherlands
 - https://doh.la.ahadns.net/dns-query
# Public DoH resolver operated by the Digital Society (https://www.digitale-gesellschaft.ch).
# Hosted in Zurich, Switzerland. Non-logging, non-filtering, supports DNSSEC.
 - dns.digitale-gesellschaft.ch/dns-query

 - 
EOF
}

# Function to create a systemd service for cloudflared
create_systemd_service() {
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
}

# Function to enable and start the cloudflared service
enable_and_start_service() {
    echo "Enabling and starting the cloudflared service"
    sudo systemctl enable cloudflared || error "Failed to enable cloudflared service"
    sudo systemctl start cloudflared || error "Failed to start cloudflared service"
    echo "Verifying that the cloudflared service is running"
    sudo systemctl status cloudflared || error "cloudflared service is not running"
}

# Function to create a cron job for updating cloudflared
create_cron_job() {
    CRON_JOB="0 0 * * * sudo wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH} && sudo chmod +x /usr/local/bin/cloudflared && sudo systemctl restart cloudflared"
    (crontab -l 2>/dev/null | grep -F "${CRON_JOB}") || true
    TEMP_CRON=$(mktemp)
    (crontab -l 2>/dev/null; echo "${CRON_JOB}") > "${TEMP_CRON}" || true
    crontab "${TEMP_CRON}" || error "Failed to create cron job"
    rm "${TEMP_CRON}"
    echo "Cron job for updating cloudflared created"
}

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