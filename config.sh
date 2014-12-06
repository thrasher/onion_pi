#!/bin/bash

# expand the filesystem
# set pi user password
# change locale to en_US (uncheck en_GB)
# do not set timezone, leave as GMT
# advanced : enable ssh
# reboot cleanly, so filesystems are properly unmounted
# verify filesystems were resized, that there are no boot error messages
# reboot cleanly once more before proceeding

function create_sd_card {
  echo "Creating an SD card is too dangerous to do from a script, so just read and execute the commands yourself in terminal"
  exit 0
  curl -L http://downloads.raspberrypi.org/raspbian/images/raspbian-2014-09-12/2014-09-09-wheezy-raspbian.zip -O
  unzip 2014-09-09-wheezy-raspbian.zip
  diskutil list disk2
  diskutil unmountDisk disk2
  # Note: on OSX, using an of=/dev/rdiskXXX (with 'r' prefix) will give 10x the write speed, which can be monitored with Ctrl-T
  sudo dd bs=1m if=2014-09-09-wheezy-raspbian.img of=/dev/disk2
}

function update {
  echo "Removing Wolfram Alpha Enginer due to bug. More info:
  http://www.raspberrypi.org/phpBB3/viewtopic.php?f=66&t=68263"
  apt-get remove -y wolfram-engine
  # unattended-upgrades monit

  # fix locale issue
  #sed -i s/en_GB/en_US/g /etc/default/locale
  #dpkg-reconfigure locales

  apt-get -y update
  apt-get -y upgrade
  apt-get -t install screen
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
  SSID=$1
  PSK=$2
  echo "Setup default WAN connection to ssid=$SSID psk=$PSK"
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
  cat > /etc/hostapd/hostapd.conf << EOF
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
  mv /usr/sbin/hostapd_cli /usr/sbin/hostapd_cli.bak
  curl https://raw.githubusercontent.com/thrasher/onion_pi/master/hostapd -o /usr/sbin/hostapd
  curl https://raw.githubusercontent.com/thrasher/onion_pi/master/hostapd_cli -o /usr/sbin/hostapd_cli

  # echo "Building hostapd from sources for the RTL8188 chip"
  #curl 'ftp://WebUser:n8W9ErCy@209.222.7.36/cn/wlan/RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Referer: http://www.realtek.com.tw/downloads/RedirectFTPSite.aspx?SiteID=6&DownTypeID=3&DownID=919&PFid=48&Conn=4&FTPPath=ftp%3a%2f%2f209.222.7.36%2fcn%2fwlan%2fRTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36' --compressed -O
  #unzip RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip
  #cd RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911/wpa_supplicant_hostapd
  #tar -xvf wpa_supplicant_hostapd-0.8_rtw_r7475.20130812.tar.gz
  #cd wpa_supplicant_hostapd-0.8_rtw_r7475.20130812/hostapd
  #make && make install

  #sudo mv hostapd /usr/sbin/hostapd
  #sudo mv hostapd_cli /usr/sbin/hostapd_cli

  sudo chown root.root /usr/sbin/hostapd /usr/sbin/hostapd_cli
  sudo chmod 755 /usr/sbin/hostapd /usr/sbin/hostapd_cli

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
  create_sd_card)
    create_sd_card
    ;;
  update)
    update
    ;;
  install_node)
    install_node
    ;;
  setup_access_point)
    setup_access_point $2 $3
    ;;
  *)
    echo "Usage: $0 { create_sd_card | update | install_node | setup_access_point [SSID] [PSK] }"
    exit 1
esac

exit 0
