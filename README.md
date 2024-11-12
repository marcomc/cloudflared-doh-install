# cloudflared-doh-install

Script to install and configure cloudflared (DoH) on RaspberryPi and GNU/Linux

## Importance of Installing cloudflared with DoH on Pi-hole

Installing cloudflared with DNS-over-HTTPS (DoH) on a Pi-hole enhances https://raw.githubusercontent.com/marcomc/cloudflared-doh-install/refs/heads/main/cloudflared-doh-install.sh of DNS data by third parties.

### Why Use cloudflared with Pi-hole?
Using cloudflared with Pi-hole to enable DNS-over-HTTPS (DoH) provides several benefits:

1. Privacy: DoH encrypts DNS queries, preventing ISPs and other entities from snooping on your browsing activity.
2. Security: Encrypted DNS queries reduce the risk of DNS spoofing and man-in-the-middle attacks.
3. Performance: Cloudflare's DNS service is known for its speed and reliability, potentially improving your browsing experience.
4. Bypass Censorship: Encrypted DNS queries can help bypass DNS-based censorship imposed by ISPs or governments.

## How to Run the Script

You can fetch and run the script using either `curl` or `wget`.

### Using curl

```sh
curl -o install.sh https://raw.githubusercontent.com/marcomc/cloudflared-doh-install/refs/heads/main/cloudflared-install.sh
chmod +x install.sh
sudo ./install.sh
```

### Using wget

```sh
wget https://raw.githubusercontent.com/marcomc/cloudflared-doh-install/refs/heads/main/cloudflared-doh-install.sh
chmod +x install.sh
sudo ./install.sh
```

## Configuring Pi-hole

After installing cloudflared, you need to configure Pi-hole to use it as a DNS-over-HTTPS (DoH) provider.

1. Open the Pi-hole admin interface.
2. Go to **Settings** > **DNS**.
3. Under **Upstream DNS Servers**, select **Custom 1 (IPv4)** and enter `127.0.0.1#5053`.
4. Scroll down and click **Save**.

For more detailed instructions, please refer to the [official Pi-hole documentation](https://docs.pi-hole.net/guides/dns/cloudflared/).