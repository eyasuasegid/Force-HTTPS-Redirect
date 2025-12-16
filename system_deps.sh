#!/bin/bash
# system_deps.sh - Install system dependencies
sudo apt update
sudo apt install -y hostapd dnsmasq socat openssl python3 iptables iproute2
echo "System dependencies installed successfully"
