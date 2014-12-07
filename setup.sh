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

function clean {
  echo "Removing Wolfram Alpha Enginer due to bug. More info:
  http://www.raspberrypi.org/phpBB3/viewtopic.php?f=66&t=68263"
  apt-get remove -y wolfram-engine
  # ntp unattended-upgrades monit

  # fix locale issue
  #sed -i s/en_GB/en_US/g /etc/default/locale
  #dpkg-reconfigure locales
}

function install {
# check if tor is already installed and customized
if [ -e /etc/tor/torrc.bak ] ; then
  echo "It appears that tor has already been configured in /etc/tor/torrc, so quitting"
  exit 1
fi

echo "This script will auto-setup a Tor proxy for you. It is recommend that you
run this script on a fresh installation of Raspbian."
read -p "Press [Enter] key to begin.."

echo "Updating package index.."
apt-get update -y

echo "Updating out-of-date packages.."
apt-get upgrade -y

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
DNSPort 53
DNSListenAddress 192.168.42.1
onion_pi_configuration

echo "Fixing firewall configuration.."
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

echo "Wiping various files and directories.."
shred -fvzu -n 3 /var/log/wtmp
shred -fvzu -n 3 /var/log/lastlog
shred -fvzu -n 3 /var/run/utmp
shred -fvzu -n 3 /var/log/mail.*
shred -fvzu -n 3 /var/log/syslog*
shred -fvzu -n 3 /var/log/messages*
shred -fvzu -n 3 /var/log/auth.log*

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

#clear
echo "Onion Pi setup complete!
To connect to your own Tor gateway, set your web browser or computer to connect to:
  Proxy type: SOCKSv5
  Port: 9050

  Transparent proxy port: 9040

Before doing anything, verify that you are using the Tor network by visiting:

  https://check.torproject.org/


Onion Pi
"

# check that tor is working
curl -s "https://check.torproject.org/" > tor-check.txt
grep "This browser is configured to use Tor" tor-check.txt
grep "Sorry. You are not using Tor." tor-check.txt

}

function dnshole {
  echo "Setting up DNSMasq"
  sudo apt-get autoremove isc-dhcp-server
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
  /etc/cron.weekly/dnsmasq.adlist.sh

  echo "restart DNSMasq to pickup new config"
  service dnsmasq restart

  echo "test on a few domains"
  dig adafruit.com
  dig doubleclick.net
}

function build_nginx {
  echo "Building nginx ..."
  # names of latest versions of each package
  VERSION_PCRE=pcre-8.36
  VERSION_OPENSSL=openssl-1.0.1j
  VERSION_NGINX=nginx-1.7.8

  # URLs to the source directories
  SOURCE_OPENSSL=https://www.openssl.org/source/
  SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
  SOURCE_NGINX=http://nginx.org/download/

  # clean out any files from previous runs of this script
  rm -rf build
  mkdir build

  # ensure that we have the required software to compile our own nginx
  sudo apt-get -y install curl wget build-essential

  # grab the source files
  wget -P ./build $SOURCE_PCRE$VERSION_PCRE.tar.gz
  wget -P ./build $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz --no-check-certificate
  wget -P ./build $SOURCE_NGINX$VERSION_NGINX.tar.gz

  # expand the source files
  cd build
  tar xzf $VERSION_NGINX.tar.gz
  tar xzf $VERSION_OPENSSL.tar.gz
  tar xzf $VERSION_PCRE.tar.gz
  cd ../

  # set where OpenSSL and nginx will be built
  BPATH=$(pwd)/build
  STATICLIBSSL="$BPATH/staticlibssl"

  # build static openssl
  cd $BPATH/$VERSION_OPENSSL
  rm -rf "$STATICLIBSSL"
  mkdir "$STATICLIBSSL"
  make clean
  ./config --prefix=$STATICLIBSSL no-shared \
  && make depend \
  && make \
  && make install_sw

  # build nginx, with various modules included/excluded
  cd $BPATH/$VERSION_NGINX
  mkdir -p $BPATH/nginx
  ./configure --with-cc-opt="-I $STATICLIBSSL/include -I/usr/include" \
  --with-ld-opt="-L $STATICLIBSSL/lib -Wl,-rpath -lssl -lcrypto -ldl -lz" \
  --sbin-path=/usr/sbin/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --pid-path=/var/run/nginx.pid \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --with-pcre=$BPATH/$VERSION_PCRE \
  --with-http_ssl_module \
  --with-http_spdy_module \
  --with-file-aio \
  --with-ipv6 \
  --with-http_gzip_static_module \
  --with-http_stub_status_module \
  --without-mail_pop3_module \
  --without-mail_smtp_module \
  --without-mail_imap_module \
  && make && make install

  echo "All done building nginx.";
}

case "$1" in
  clean)
    clean
    ;;
  install)
    install
    dnshole
    build_nginx
    ;;
  *)
    echo "Usage: $0 { clean | install }"
    exit 1
esac
exit 0
