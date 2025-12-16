#!/bin/bash
clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              STOPPING HTTPS DEMO                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "┌─ Stopping Services ─────────────────────────────────────────┐"
echo "│ 🛑 Stopping all demo services...                           │"

# Kill all processes
sudo pkill -9 hostapd 2>/dev/null
sudo pkill -9 dnsmasq 2>/dev/null
sudo pkill -f "http.server" 2>/dev/null
sudo pkill -f smart_server.py 2>/dev/null
sudo pkill -f socat 2>/dev/null
sudo pkill -f stunnel 2>/dev/null
sudo pkill -f watch 2>/dev/null

echo "│    ✓ Processes stopped                                      │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

echo "┌─ Clearing Firewall Rules ────────────────────────────────────┐"
# Clear iptables
sudo iptables -F 2>/dev/null
sudo iptables -t nat -F 2>/dev/null
echo "│    ✓ Firewall rules cleared                                 │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

echo "┌─ Restoring Network ──────────────────────────────────────────┐"
# Restart NetworkManager
sudo systemctl start NetworkManager 2>/dev/null
sudo ip link set wlan0 down 2>/dev/null
sudo ip link set wlan0 up 2>/dev/null
echo "│    ✓ Network restored                                       │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ✅ HTTPS DEMO STOPPED SUCCESSFULLY!                      ║"
echo "║     Network restored to normal.                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
