#!/bin/bash

function dnshole {
  sudo apt-get autoremove isc-dhcp-server
  sudo apt-get install -y dnsmasq dnsutils

  # see  /etc/dnsmasq.conf for more config options
  echo "conf-dir=/etc/dnsmasq.d" >> /etc/dnsmasq.conf

  # Any files added to the directory /etc/dnsmasq.d are automatically loaded by dnsmasq after a restart.
  cat >> /etc/dnsmasq.d/dnsmasq.custom.conf << EOF
interface=wlan1
#except-interface=wlan0
bind-interfaces

log-dhcp
log-queries

dhcp-range=wlan1,192.168.42.10,192.168.42.50,2h

# Gateway
dhcp-option=3,192.168.42.1

# DNS
dhcp-option=6,192.168.42.1
 
dhcp-authoritative
EOF

  cp -ap /etc/resolv.conf /etc/resolv.conf.bak
  cat > /etc/resolv.conf << EOF
nameserver 192.168.42.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

  echo "restart DNSMasq to pickup new config"
  service dnsmasq restart

  update-rc.d dnsmasq enable
  dig adafruit.com
}

dnshole

