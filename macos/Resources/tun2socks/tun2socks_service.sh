#!/bin/bash

# Service script executed via launchd to run tun2socks and configure routing
PROXY="socks5://127.0.0.1:1080"
TUN_DEV="utun123"
TUN_IP="198.18.0.1"
IFACE="en0"

ifconfig "$TUN_DEV" "$TUN_IP" "$TUN_IP" up

for net in 1.0.0.0/8 2.0.0.0/7 4.0.0.0/6 8.0.0.0/5 \
           16.0.0.0/4 32.0.0.0/3 64.0.0.0/2 128.0.0.0/1 \
           198.18.0.0/15; do
  route add -net "$net" "$TUN_IP"
done

exec tun2socks -device "$TUN_DEV" -proxy "$PROXY" -interface "$IFACE"
