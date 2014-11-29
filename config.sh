#!/bin/bash

# expand the filesystem
# set pi user password
# change locale to en_US (uncheck (en_GB)
# advanced : enable ssh

function update {
  apt-get -y update
  apt-get -y upgrade
}

function install_node {
  echo "Installing Node.js"
  curl http://nodejs.org/dist/v0.10.28/node-v0.10.28-linux-arm-pi.tar.gz -O
  tar -xvzf node-v0.10.28-linux-arm-pi.tar.gz
  mv node-v0.10.28-linux-arm-pi /usr/bin/.
  ln -s /usr/bin/node-v0.10.28-linux-arm-pi /usr/bin/node
  cat >> /etc/environment << EOF
NODE_JS_HOME=/usr/bin/node
EOF
  cat >> ~/.profile << EOF
NODE_JS_HOME=/usr/bin/node
export PATH=\$PATH:\$NODE_JS_HOME/bin
EOF
  . ~/.profile
  node --version
  npm version
  gcc --version

  # optional: install the native bridge
  npm install -g node-gyp
}

function setup_access_point {
  # roughly follows: https://learn.adafruit.com/setting-up-a-raspberry-pi-as-a-wifi-access-point?view=all
  SSID=$2
  PSK=$3
  echo "Setting up Access Point, assuming wlan0 for WAN and wlan1 for LAN"
  apt-get install -y hostapd isc-dhcp-server
  cp -ap /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
  echo "Configuring DHCP server in /etc/dhcp/dhcpd.conf"
  sed -i 's/^\(option.*example.org.*\)/#\1/g' /etc/dhcp/dhcpd.conf
  sed -i 's/#authoritative;/authoritative;/g' /etc/dhcp/dhcpd.conf
  cat >> /etc/dhcp/dhcpd.conf << EOF
# see: https://learn.adafruit.com/setting-up-a-raspberry-pi-as-a-wifi-access-point/install-software
subnet 192.168.42.0 netmask 255.255.255.0 {
  range 192.168.42.10 192.168.42.50;
  option broadcast-address 192.168.42.255;
  option routers 192.168.42.1;
  default-lease-time 600;
  max-lease-time 7200;
  option domain-name "local";
  option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

  echo "Configuring /etc/default/isc-dhcp-server"
  cp -ap /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak
  sed -i 's/^INTERFACES=.*/INTERFACES="wlan1"/g' /etc/default/isc-dhcp-server

  echo "Configuring static IP for LAN /etc/network/interfaces"
  ifdown wlan1
  cp -ap /etc/network/interfaces /etc/network/interfaces.bak
  cat > /etc/network/interfaces << EOF
auto lo

iface lo inet loopback
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
wpa-ssid $SSID
wpa-psk $PSK

auto wlan1
iface wlan1 inet static
address 192.168.42.1
netmask 255.255.255.0

EOF
  echo "Assigning a static IP to the wlan1 adapter"
  ifconfig wlan1 192.168.42.1

  echo "Setup WiFi Access Point LAN"
  echo > /etc/hostapd/hostapd.conf << EOF
interface=wlan1
driver=rtl871xdrv
ssid=OnionPi
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=0freedom
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

  cp -ap /etc/default/hostapd /etc/default/hostapd.bak
  sed -i 's/#DAEMON_CONF.*/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' /etc/default/hostapd

  echo "Configuring Network Address Translation"
  cp -ap /etc/sysctl.conf /etc/sysctl.conf.bak
  sed -i 's/^#net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

  echo "Activating NAT immediately"
  sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

  echo "Configuring iptables"
  iptables -F
  iptables -t nat -F
  iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
  iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT

  iptables -t nat -S
  iptables -S

  sh -c "iptables-save > /etc/iptables.ipv4.nat"
  cat >> /etc/network/interfaces << EOF
up iptables-restore < /etc/iptables.ipv4.nat
EOF

  echo "Downloading and installing hostapd for Realtek Semiconductor Corp. RTL8188CUS 802.11n WLAN Adapter"
  mv /usr/sbin/hostapd /usr/sbin/hostapd.bak
  curl https://raw.githubusercontent.com/thrasher/onion_pi/master/hostapd -O
  chmod 755 hostapd
  chown root:root hostapd
  mv hostapd /usr/sbin/hostapd

  echo "Disabling WPASupplicant"
  mv /usr/share/dbus-1/system-services/fi.epitest.hostap.WPASupplicant.service ~/

  echo "Setup DHCP and Access Point to start on boot"
  update-rc.d hostapd enable
  update-rc.d isc-dhcp-server enable
  service hostapd start
  service isc-dhcp-server start

  echo "Reboot your Raspberry Pi to see if your AP works!"
}

case "$1" in
  update)
    update
    ;;
  install_node)
    install_node
    ;;
  setup_access_point)
    setup_access_point
    ;;
  *)
    echo "Usage: $0 { update | install_node | setup_access_point [SSID] [PSK] }"
    exit 1
esac

exit 0
