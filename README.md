# Force HTTPS Redirect
A powerful WiFi hotspot tool that demonstrates HTTPS interception using a proper SSL/TLS certificate chain. This tool creates a WiFi access point that intercepts and redirects all HTTP/HTTPS traffic to a custom landing page, perfect for security demonstrations and educational purposes.

## 🎯 Features

- **WiFi Hotspot Creation**: Create open or WPA2-protected WiFi access points
- **DNS Hijacking**: Redirects all DNS queries to your server
- **HTTPS Interception**: SSL/TLS termination with proper certificate chain
- **HTTP/HTTPS Redirection**: All traffic redirected to your custom HTML page
- **Certificate Management**: Automatic certificate generation and management
- **Real-time Monitoring**: Track connected devices and access logs
- **Cross-platform**: Works on Linux (Debian/Ubuntu/Kali)

## 📋 Requirements

- Linux system (Debian/Ubuntu/Kali recommended)
- Root/sudo access
- WiFi adapter (wlan0)
- Python 3
- Internet connection (for initial setup)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd redirect
```

### 2. Install System Dependencies

```bash
chmod +x system_deps.sh
sudo ./system_deps.sh
```

This will install:
- `hostapd` - WiFi access point daemon
- `dnsmasq` - DNS and DHCP server
- `socat` - SSL/TLS proxy
- `openssl` - Certificate generation
- `python3` - HTTP server
- `iptables` - Firewall rules
- `iproute2` - Network utilities

### 3. Create SSL Certificates

```bash
chmod +x cert.sh
sudo ./cert.sh
```

This creates a complete certificate chain:
- Root CA certificate (valid 10 years)
- Intermediate CA certificate (valid 5 years)
- Server certificate (valid 1 year)

Certificates are stored in `/etc/ssl/https_demo_certs/` (permanent location).

### 4. Prepare Your HTML Landing Page

Create a directory with your HTML file:

```bash
mkdir -p ~/my_html
echo "<html><body><h1>Welcome!</h1></body></html>" > ~/my_html/index.html
```

Or use an existing directory with HTML files.

### 5. Run the Demo

```bash
chmod +x main.sh
sudo ./main.sh
```

The script will prompt you for:
- **HTML Directory**: Path to your HTML files directory
- **Hotspot SSID**: Name of your WiFi network
- **Security**: Open (no password) or WPA2 (with password)
- **Password**: If WPA2 is selected (minimum 8 characters)

## 📖 Detailed Usage

### Running the Demo

When you run `sudo ./main.sh`, you'll be guided through setup with a beautiful structured interface.

### What Happens

1. **Hotspot Created**: WiFi network becomes available
2. **DNS Hijacking**: All DNS queries resolve to `192.168.123.1`
3. **SSL Proxy**: HTTPS traffic is intercepted and terminated
4. **HTTP Server**: Serves your HTML page for all requests
5. **Traffic Isolation**: Clients cannot access the real internet

### Certificate Installation (For HTTPS to Work)

To avoid browser certificate warnings, clients must install the Root CA certificate:

1. **Download**: Connect to the hotspot and visit `http://192.168.123.1/client.crt`
2. **Install**: Follow platform-specific instructions (see below)
3. **Restart**: Restart browser/device
4. **Test**: Visit any HTTPS site - should work without warnings!

#### Platform-Specific Installation

**Android:**
- Settings → Security → Advanced → Encryption & credentials
- Install from storage → Select `client.crt`
- Name it "Demo Root CA" → Install
- Restart device

**iOS:**
- Settings → General → VPN & Device Management
- Install Profile → Select `client.crt`
- Settings → General → About → Certificate Trust Settings
- Enable "Security Demo Root CA"
- Restart device

**Windows:**
- Double-click `client.crt`
- Install Certificate → Local Machine
- Place in "Trusted Root Certification Authorities"
- Restart browser

**Linux (Chrome/Chromium):**
- Settings → Privacy and Security → Security → Manage certificates
- Authorities tab → Import `client.crt`
- Trust for websites
- Restart browser

**macOS:**
- Double-click `client.crt` → Keychain Access opens
- Find "Security Demo Root CA"
- Set Trust to "Always Trust"
- Restart browser

## 🛑 Stopping the Demo

To stop all services and restore network:

```bash
chmod +x stop_perfect.sh
sudo ./stop_perfect.sh
```

This will:
- Stop all running services (hostapd, dnsmasq, socat, HTTP server)
- Clear firewall rules
- Restart NetworkManager
- Restore network to normal

## 📊 Monitoring

### View Access Logs

```bash
# Real-time access log
tail -f /tmp/access.log

# Last 10 entries
tail -10 /tmp/access.log
```

### View Connected Devices

```bash
sudo ip neigh show dev wlan0 | grep 192.168.123 | grep -v 192.168.123.1
```

### View Service Logs

```bash
# Hostapd logs
tail -f /tmp/hostapd.log

# DNS logs
tail -f /tmp/dnsmasq.log

# SSL proxy logs
tail -f /tmp/socat.log

# HTTP server logs
tail -f /tmp/http_server.log
```

## 📁 Project Structure

```
redirect/
├── README.md              # This file
├── system_deps.sh         # Install system dependencies
├── cert.sh                # Generate SSL certificates
├── main.sh                  # Main demo script
├── stop_perfect.sh        # Stop all services

```

## 🔧 Configuration

### Certificate Storage

Certificates are stored permanently in:
```
/etc/ssl/https_demo_certs/
├── root-ca.crt           # Root CA (install in browsers)
├── root-ca.key           # Root CA private key
├── intermediate-ca.crt   # Intermediate CA
├── intermediate-ca.key   # Intermediate CA private key
├── server.crt            # Server certificate
├── server.key            # Server private key
└── server-chain.crt      # Full certificate chain
```

### Network Configuration

- **Gateway IP**: `192.168.123.1`
- **Network**: `192.168.123.0/24`
- **DHCP Range**: `192.168.123.100-200`
- **HTTP Port**: `80`
- **HTTPS Port**: `443`

### HTML File Selection

The script automatically finds the first `.html` file in your specified directory:
- Searches for `*.html` files
- Uses the first one found as the landing page
- Serves it for all requests (except `/client.crt`)

## 🧪 Testing with curl

Test HTTPS connections using the Root CA certificate:

```bash
# Basic test
curl --cacert /etc/ssl/https_demo_certs/root-ca.crt https://127.0.0.1/

# Verbose (see SSL details)
curl -v --cacert /etc/ssl/https_demo_certs/root-ca.crt https://google.com

# Test any domain (DNS hijacked)
curl --cacert /etc/ssl/https_demo_certs/root-ca.crt https://facebook.com
```

## ⚠️ Important Notes

### Security & Legal

- **Educational Purpose Only**: This tool is for security education and authorized testing
- **Authorized Use Only**: Only use on networks you own or have explicit permission to test
- **Legal Compliance**: Ensure compliance with local laws regarding network interception
- **Not for Production**: Do not use in production environments

### Technical Limitations

- Requires root/sudo access
- WiFi adapter must support AP mode
- May interfere with existing network services
- Certificates are self-signed (not trusted by default)

## 🔧 Troubleshooting

### Hotspot not starting
- Check if `wlan0` exists: `ip link show wlan0`
- Ensure WiFi is not blocked: `sudo rfkill unblock wifi`
- Check hostapd logs: `tail -f /tmp/hostapd.log`

### Certificates not working
- Regenerate certificates: `sudo ./cert.sh`
- Verify certificate chain: `sudo openssl verify -CAfile /etc/ssl/https_demo_certs/root-ca.crt -untrusted /etc/ssl/https_demo_certs/intermediate-ca.crt /etc/ssl/https_demo_certs/server.crt`

### DNS not hijacking
- Check dnsmasq is running: `ps aux | grep dnsmasq`
- Verify DNS logs: `tail -f /tmp/dnsmasq.log`
- Test DNS: `nslookup google.com` (should return 192.168.123.1)

### HTTPS not working
- Ensure Root CA is installed in browser
- Check socat is running: `ps aux | grep socat`
- Verify SSL logs: `tail -f /tmp/socat.log`

## 🔄 Regenerating Certificates

To create fresh certificates:

```bash
sudo ./cert.sh
```

This will:
- Delete old certificates
- Generate new Root CA, Intermediate CA, and Server certificates
- Store them in `/etc/ssl/https_demo_certs/`

**Note**: After regenerating, clients must download and install the new Root CA certificate.

## 📝 Log Files

All logs are stored in `/tmp/`:

- `/tmp/access.log` - HTTP access log (client requests)
- `/tmp/hostapd.log` - WiFi hotspot logs
- `/tmp/dnsmasq.log` - DNS server logs
- `/tmp/socat.log` - SSL proxy logs
- `/tmp/http_server.log` - HTTP server logs

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is provided for educational purposes. Use responsibly and in compliance with applicable laws.

## 🙏 Acknowledgments

Built for security education and demonstration purposes. Use responsibly!

---

**⚠️ DISCLAIMER**: This tool is for educational and authorized testing purposes only. Users are responsible for ensuring compliance with all applicable laws and regulations. The authors assume no liability for misuse of this software.
