# cloudflared-install

Script to install and configure cloudflared on RaspberryPI and GNU/Linux

## How to Run the Script

You can fetch and run the script using either `curl` or `wget`.

### Using curl

```sh
curl -O https://raw.githubusercontent.com/yourusername/cloudflared-install/main/install.sh
chmod +x install.sh
./install.sh
```

### Using wget

```sh
wget https://raw.githubusercontent.com/yourusername/cloudflared-install/main/install.sh
chmod +x install.sh
./install.sh
```

## Configuring Pi-hole

After installing cloudflared, you need to configure Pi-hole to use it as a DNS-over-HTTPS (DoH) provider.

1. Open the Pi-hole admin interface.
2. Go to **Settings** > **DNS**.
3. Under **Upstream DNS Servers**, select **Custom 1 (IPv4)** and enter `127.0.0.1#5053`.
4. Scroll down and click **Save**.
