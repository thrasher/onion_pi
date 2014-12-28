Onion Pi
========

Make a Raspberry Pi into a Anonymizing Tor Proxy! 

This repo was inspired in part by Adafruit's tutorial in setting up a Raspberry
Pi for use as a Tor Proxy. For more information, visit: http://learn.adafruit.com/onion-pi

Setup
-----
Setting up and installing your Onion Pi couldn't be easier. Copy & paste the following
commands into your terminal and follow the commands provided

    curl -fsSL https://raw.githubusercontent.com/thrasher/onion_pi/master/setup.sh | sudo sh

possible configurations

Assume: we always run Nginx and Node.js for configuration support.

1) DNS for ad blocking
- requires pointing at RPi from router for DNS
  dnsmasq listening on ipaddress on network
  no DHCP server
  no iptables config required
  run DNSMasq
  clear iptable rules
  don't care if Tor is running or not
  requires setting clients, or DHCP server, to point to RPi for DNS
  configure DNSMasq to use Google DNS as fallback

2) hotspot
  no ad-block, no-tor
  just forwards packets
  use DNSMasq DHCP server
  use hostapd for WiFi hostspot

3) tor hotspot
  requires iptables to route packets to tor
  use DNSMasq in front of Tor to cache DNS queries

4) adblock hotspot

5) tor + adblock hotspot
  requires iptables to route packets to tor
  requires dnsmasq to cache/block ads
  dnsmasq -> tor for DNS queries

