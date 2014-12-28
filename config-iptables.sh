#!/bin/sh

access_point() {
  echo "Configuring iptables as Access Point"
  iptables -F
  iptables -t nat -F
  iptables -t nat -A PREROUTING -i wlan1 -p tcp --dport 22 -j REDIRECT --to-ports 22 -m comment --comment "Allow SSH to Raspberry Pi"
  iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
  iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT

  iptables -t nat -S
  iptables -S

  sh -c "iptables-save > /etc/iptables.ipv4.nat"
}

tor() {
  echo "Configuring iptables for Tor"
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
  access_point)
    access_point
    ;;

  tor)
    tor
    ;;

  *)
    echo "Usage: $NAME {access_point|tor}" >&2
    exit 1
    ;;
esac

exit 0
