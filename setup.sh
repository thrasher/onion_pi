#!/bin/bash
# Onion Pi, based on the Adafruit Learning Technologies Onion Pi project.
# For more info: http://learn.adafruit.com/onion-pi
#
# To do:
# * Options for setting up relay, exit, or bridge
# * More anonymization of Onion Pi box
# * Further testing

if (( $EUID != 0 )); then
  echo "This script must be run as root. Type in 'sudo $0' to run it as root."
  exit 1
fi

cat <<'Onion_Pi'
                            ~
                           /~
                     \  \ /**
                      \ ////
                      // //
                     // //
                   ///&//
                  / & /\ \
                /  & .,,  \
              /& %  :       \
            /&  %   :  ;     `\
           /&' &..%   !..    `.\
          /&' : &''" !  ``. : `.\
         /#' % :  "" * .   : : `.\
        I# :& :  !"  *  `.  : ::  I
        I &% : : !%.` '. . : : :  I
        I && :%: .&.   . . : :  : I
        I %&&&%%: WW. .%. : :     I
         \&&&##%%%`W! & '  :   ,'/
          \####ITO%% W &..'  #,'/
            \W&&##%%&&&&### %./
              \###j[\##//##}/
                 ++///~~\//_
                  \\ \ \ \  \_
                  /  /    \
Onion_Pi

function create_sd_card {
  echo "Creating an SD card is too dangerous to do from a script, so just read and execute the commands yourself in terminal"
  exit 0
  curl -L http://downloads.raspberrypi.org/raspbian/images/raspbian-2014-09-12/2014-09-09-wheezy-raspbian.zip -O
  unzip 2014-09-09-wheezy-raspbian.zip
  diskutil list
  diskutil unmountDisk disk2
  # Note: on OSX, using an of=/dev/rdiskXXX (with 'r' prefix) will give 10x the write speed, which can be monitored with Ctrl-T
  sudo dd bs=1m if=2014-09-09-wheezy-raspbian.img of=/dev/rdisk2
  sudo diskutil eject /dev/rdisk2
}

# expand the filesystem
# set pi user password
# change locale to en_US (uncheck en_GB)
# do not set timezone, leave as GMT
# advanced : enable ssh
# reboot cleanly, so filesystems are properly unmounted
# verify filesystems were resized, that there are no boot error messages
# reboot cleanly once more before proceeding

function clean {
  echo "Removing Wolfram Alpha Enginer due to bug. More info:
  http://www.raspberrypi.org/phpBB3/viewtopic.php?f=66&t=68263"
  apt-get remove -y wolfram-engine

  # fix locale issue
  #sed -i s/en_GB/en_US/g /etc/default/locale
  #dpkg-reconfigure locales

  apt-get -y update
  apt-get -y upgrade
  apt-get -y install vim screen curl wget ntp monit build-essential dnsmasq dnsutils tor unattended-upgrades

  echo "Setting up unattended upgrades, note that we're not configuring for auto-reboot, but some updates may need it"
  #dpkg-reconfigure -plow unattended-upgrades
  cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

  # additional config
  #echo "Turning swap off, to reduce writes to the SD Card"
  #sudo dphys-swapfile swapoff

  # Set name of pi user
  chfn -f "OnionPi" pi
}

function build_all {
  echo "Building external binaries"

  DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

  echo "Installing hostapd"
  apt-get -y install hostapd
  sh $DIR/build-hostapd.sh

  echo "Picking up nginx config files, the sloppy way"
  apt-get -y install nginx
  apt-get -y autoremove nginx
  mv /etc/nginx /etc/nginx-old
  sh $DIR/build-nginx.sh
  #cp -rp nginx /etc
  #chown -R root:root /etc/nginx

  echo "Configure node"
  sh $DIR/build-node.sh
  sudo tar -xvf node-v0.10.33-linux-arm-pi.tar.gz -C /usr/local
  sudo ln -s /usr/local/node-v0.10.33-linux-arm-pi /usr/local/node
  ln -s /usr/local/node/bin/node /usr/sbin/node
  ln -s /usr/local/node/bin/npm /usr/sbin/npm
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
  #apt-get install -y hostapd
  apt-get install -y isc-dhcp-server
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
# sets the wifi interface to use, is wlan0 in most cases
interface=wlan1
# driver to use, nl80211 works in most cases
driver=rtl871xdrv
# sets the ssid of the virtual wifi access point
ssid=OnionPi
# sets the mode of wifi, depends upon the devices you will be using. It can be a,b,g,n. Setting to g ensures backward compatiblity.
hw_mode=g
# sets the channel for your wifi
channel=6
# macaddr_acl sets options for mac address filtering. 0 means "accept unless in deny list"
#macaddr_acl=0
# Sets authentication algorithm
# 1 - only open system authentication
# 2 - both open system authentication and shared key authentication
#auth_algs=1
# setting ignore_broadcast_ssid to 1 will disable the broadcasting of ssid
#ignore_broadcast_ssid=0
#####Sets WPA and WPA2 authentication#####
# wpa option sets which wpa implementation to use
# 1 - wpa only
# 2 - wpa2 only
# 3 - both
#wpa=2
# sets wpa passphrase required by the clients to authenticate themselves on the network
#wpa_passphrase=0freedom
# sets wpa key management
#wpa_key_mgmt=WPA-PSK
# sets encryption used by WPA
#wpa_pairwise=TKIP
# sets encryption used by WPA2
#rsn_pairwise=CCMP
#################################
#####Sets WEP authentication#####
# WEP is not recommended as it can be easily broken into
#wep_default_key=0
#wep_key0=qwert    #5,13, or 16 characters
# optionally you may also define wep_key2, wep_key3, and wep_key4
#################################
#For No encryption, you don't need to set any options
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

function install_tor {
#read -p "Press [Enter] key to install tor"

echo "Downloading and installing various packages.."
apt-get install -y tor
service tor stop

echo "Configuring Tor.."
cp -ap /etc/tor/torrc /etc/tor/torrc.bak
cat >> /etc/tor/torrc << 'onion_pi_configuration'
## Onion Pi Config v0.3
## More information: https://github.com/breadtk/onion_pi/

# Configure proxy server service for a network of computers
VirtualAddrNetwork 10.192.0.0/10

# Transparent proxy port
TransPort 9040
TransListenAddress 192.168.42.1

# Explicit SOCKS port for applications.
SocksPort 9050

# Port that Tor will output 'info' level logs to.
Log notice file /var/log/tor/notices.log

# Have Tor run in the background
RunAsDaemon 1

# Only ever run as a client. Do not run as a relay or an exit.
ClientOnly

# Ensure resolution of .onion and .exit domains happen through Tor.
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1

# Serve DNS responses
DNSPort 9053
DNSListenAddress 192.168.42.1
onion_pi_configuration

echo "Wiping various files and directories.."
#shred -fvzu -n 3 /var/log/wtmp
#shred -fvzu -n 3 /var/log/lastlog
#shred -fvzu -n 3 /var/run/utmp
#shred -fvzu -n 3 /var/log/mail.*
#shred -fvzu -n 3 /var/log/syslog*
#shred -fvzu -n 3 /var/log/messages*
#shred -fvzu -n 3 /var/log/auth.log*

echo "Setting up logging in /var/log/tor/notices.log.."
touch /var/log/tor/notices.log
chown debian-tor /var/log/tor/notices.log
chmod 644 /var/log/tor/notices.log

echo "Setting tor to start at boot.."
update-rc.d tor enable

echo "Setting up Monit to watch Tor process.."
apt-get install -y monit
cp -ap /etc/monit/monitrc /etc/monit/monitrc.bak
cat >> /etc/monit/monitrc << 'tor_monit'
check process tor with pidfile /var/run/tor/tor.pid
group tor
start program = "/etc/init.d/tor start"
stop program = "/etc/init.d/tor stop"
if failed port 9050 type tcp
   with timeout 5 seconds
   then restart
if 3 restarts within 5 cycles then timeout
tor_monit

echo "Starting monit.."
monit quit
monit -c /etc/monit/monitrc

echo "Starting tor.."
service tor start

# check that tor is working
#curl -s "https://check.torproject.org/" > tor-check.txt
}

function install_dnsmasq {
  #read -p "Press [Enter] key to install DNSMasq"
  echo "Setting up DNSMasq"
  service isc-dhcp-server stop
  sudo apt-get -y autoremove isc-dhcp-server
  sudo apt-get install -y dnsmasq dnsutils

  # see  /etc/dnsmasq.conf for more config options
  echo "conf-dir=/etc/dnsmasq.d" >> /etc/dnsmasq.conf

  # Any files added to the directory /etc/dnsmasq.d are automatically loaded by dnsmasq after a restart.
  cat >> /etc/dnsmasq.d/dnsmasq.custom.conf << EOF
interface=wlan1
#except-interface=wlan0
bind-interfaces

no-resolv
listen-address=192.168.42.1
server=192.168.42.1#9053

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
#nameserver 8.8.8.8
#nameserver 8.8.4.4
EOF

  update-rc.d dnsmasq enable

  echo "Setup weekly cron to update ad-hosts"
  cp dnsmasq.adlist.sh /etc/cron.weekly/.
  sh /etc/cron.weekly/dnsmasq.adlist.sh
  cp adlist.conf /etc/dnsmasq.d

  echo "restart DNSMasq to pickup new config"
  service dnsmasq restart

  echo "test on a few domains"
  dig adafruit.com
  dig doubleclick.net
}

function config_iptables {
  echo "Fixing firewall configuration... routing wlan1 to dnsmasq to tor's DNSPort, and Ads to nginx"
  iptables -F
  iptables -t nat -F
  iptables -t nat -A PREROUTING -i wlan1 -p tcp --dport 22 -j REDIRECT --to-ports 22 -m comment --comment "Allow SSH to Raspberry Pi"
  iptables -t nat -A PREROUTING -i wlan1 -p tcp --dport 80  --source 192.168.0.0/16 --destination 192.168.42.1 -j REDIRECT --to-ports 80 -m comment --comment "Redirect ads to local nginx"
  iptables -t nat -A PREROUTING -i wlan1 -p udp --dport 53 -j REDIRECT --to-ports 53 -m comment --comment "OnionPi: Redirect all DNS requests to local DNS server (DNSMasq or Tor's DNSPort)."
  iptables -t nat -A PREROUTING -i wlan1 -p tcp --syn -j REDIRECT --to-ports 9040 -m comment --comment "OnionPi: Redirect all TCP packets to Tor's TransPort port."
  
  echo "Fixing bug in firewall rules https://lists.torproject.org/pipermail/tor-talk/2014-March/032507.html"
  #iptables -A OUTPUT -m conntrack --ctstate INVALID -j LOG --log-prefix "Transproxy ctstate leak blocked: " --log-uid
  iptables -A OUTPUT -m conntrack --ctstate INVALID -j DROP
  #iptables -A OUTPUT -m state --state INVALID -j LOG --log-prefix "Transproxy state leak blocked: " --log-uid
  iptables -A OUTPUT -m state --state INVALID -j DROP
  
  #iptables -A OUTPUT ! -o lo ! -d 127.0.0.1 ! -s 127.0.0.1 -p tcp -m tcp --tcp-flags ACK,FIN ACK,FIN -j LOG --log-prefix "Transproxy leak blocked: " --log-uid
  #iptables -A OUTPUT ! -o lo ! -d 127.0.0.1 ! -s 127.0.0.1 -p tcp -m tcp --tcp-flags ACK,RST ACK,RST -j LOG --log-prefix "Transproxy leak blocked: " --log-uid
  iptables -A OUTPUT ! -o lo ! -d 127.0.0.1 ! -s 127.0.0.1 -p tcp -m tcp --tcp-flags ACK,FIN ACK,FIN -j DROP
  iptables -A OUTPUT ! -o lo ! -d 127.0.0.1 ! -s 127.0.0.1 -p tcp -m tcp --tcp-flags ACK,RST ACK,RST -j DROP
  
  echo "These are the iptables"
  iptables -t nat -L -v
  iptables -L -v
  
  sh -c "iptables-save > /etc/iptables.ipv4.nat"
}

case "$1" in
  clean)
    clean
    build_all
    ;;
  install)
    setup_access_point $2 $3
    install_tor
    install_dnsmasq
    config_iptables
    ;;
  *)
    echo "Usage: $0 { clean | install [SSID] [PSK] }"
    exit 1
esac
exit 0
