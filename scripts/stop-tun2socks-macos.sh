#!/bin/bash
TUN_DEV="utun123"

echo "[*] Stopping tun2socks..."

for net in 0.0.0.0/1 128.0.0.0/1 198.18.0.0/15; do
  sudo route -n delete -net "$net" 2>/dev/null || true
done

sudo pkill -f "tun2socks.*$TUN_DEV" || true
sudo ifconfig "$TUN_DEV" down 2>/dev/null || true

echo "[*] tun2socks stopped and routes cleared."
