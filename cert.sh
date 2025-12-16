#!/bin/bash

echo "=== CREATING CERTIFICATE CHAIN FOR HTTPS DEMO ==="

CERT_DIR="/etc/ssl/https_demo_certs"

# Create certificate directory
echo "Creating certificate directory: $CERT_DIR"
sudo mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Clean up old certificates
echo "Cleaning up old certificates..."
sudo rm -f *.key *.crt *.csr *.srl *.cnf

# 1. Create Root CA
echo "Creating Root CA..."
cat > root-ca.cnf << 'EOF'
[ req ]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ca

[ dn ]
C = US
ST = California
L = San Francisco
O = Security Demo Lab
CN = Security Demo Root CA

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

sudo openssl genrsa -out root-ca.key 4096 2>/dev/null
sudo openssl req -x509 -new -nodes -key root-ca.key -sha256 -days 3650 \
  -out root-ca.crt -config root-ca.cnf 2>/dev/null

# 2. Create Intermediate CA (signed by Root CA)
echo "Creating Intermediate CA..."
cat > intermediate-ca.cnf << 'EOF'
[ req ]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
C = US
ST = California
L = San Francisco
O = Security Demo Lab
CN = Security Demo Intermediate CA
EOF

sudo openssl genrsa -out intermediate-ca.key 4096 2>/dev/null
sudo openssl req -new -key intermediate-ca.key -out intermediate-ca.csr -config intermediate-ca.cnf 2>/dev/null

# Sign Intermediate CA with Root CA
cat > intermediate-ext.cnf << 'EOF'
authorityKeyIdentifier = keyid,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

sudo openssl x509 -req -in intermediate-ca.csr -CA root-ca.crt -CAkey root-ca.key \
  -CAcreateserial -out intermediate-ca.crt -days 1825 -sha256 \
  -extfile intermediate-ext.cnf 2>/dev/null

# 3. Create Server Certificate (signed by Intermediate CA)
echo "Creating Server Certificate..."
cat > server.cnf << 'EOF'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
C = US
ST = California
L = San Francisco
O = Security Demo Lab
CN = *.demo.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.demo.local
DNS.2 = *.demo.com
DNS.3 = demo.local
DNS.4 = localhost
IP.1 = 192.168.123.1
IP.2 = 127.0.0.1
EOF

sudo openssl genrsa -out server.key 2048 2>/dev/null
sudo openssl req -new -key server.key -out server.csr -config server.cnf 2>/dev/null

# Sign Server Certificate with Intermediate CA
cat > server-ext.cnf << 'EOF'
authorityKeyIdentifier = keyid,issuer:always
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names
extendedKeyUsage = serverAuth

[ alt_names ]
DNS.1 = *.demo.local
DNS.2 = *.demo.com
DNS.3 = demo.local
DNS.4 = localhost
IP.1 = 192.168.123.1
IP.2 = 127.0.0.1
EOF

sudo openssl x509 -req -in server.csr -CA intermediate-ca.crt -CAkey intermediate-ca.key \
  -CAcreateserial -out server.crt -days 365 -sha256 \
  -extfile server-ext.cnf 2>/dev/null

# 4. Create certificate chain file
cat server.crt intermediate-ca.crt > server-chain.crt

# 5. Set proper permissions
sudo chmod 644 *.crt
sudo chmod 600 *.key

# 6. Verify the certificate chain
echo "Verifying certificate chain..."
if sudo openssl verify -CAfile root-ca.crt -untrusted intermediate-ca.crt server.crt; then
    echo "✅ Certificate chain is valid"
else
    echo "❌ Certificate chain verification failed"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ CERTIFICATES CREATED SUCCESSFULLY!"
echo "========================================"
echo ""
echo "📁 Certificate Directory: $CERT_DIR"
echo ""
echo "📜 Generated Certificates:"
echo "  • root-ca.key/crt          - Root Certificate Authority"
echo "  • intermediate-ca.key/crt  - Intermediate CA"
echo "  • server.key/crt           - Server certificate"
echo "  • server-chain.crt         - Full certificate chain"
echo ""
echo "🔍 Certificate Details:"
echo "  Root CA:         Security Demo Root CA"
echo "  Intermediate CA: Security Demo Intermediate CA"
echo "  Server:          *.demo.local (wildcard)"
echo "  Valid Domains:   *.demo.local, *.demo.com, demo.local, localhost"
echo "  Valid IPs:       192.168.123.1, 127.0.0.1"
echo ""
echo "🚀 Now run: sudo ./https_demo.sh"
echo "========================================"
