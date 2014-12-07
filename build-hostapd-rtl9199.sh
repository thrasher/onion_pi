#!/bin/bash

echo "Building hostapd from sources for the RTL8188 chip used in common Raspberry Pi USB WiFi adapters"

curl 'ftp://WebUser:n8W9ErCy@209.222.7.36/cn/wlan/RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Referer: http://www.realtek.com.tw/downloads/RedirectFTPSite.aspx?SiteID=6&DownTypeID=3&DownID=919&PFid=48&Conn=4&FTPPath=ftp%3a%2f%2f209.222.7.36%2fcn%2fwlan%2fRTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36' --compressed -O

unzip RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip
cd RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911/wpa_supplicant_hostapd
tar -xvf wpa_supplicant_hostapd-0.8_rtw_r7475.20130812.tar.gz
cd wpa_supplicant_hostapd-0.8_rtw_r7475.20130812/hostapd

#make && make install
make

echo "installing hostapd manually, as the makefile has the wrong path for raspberry pi"
cd $PWD
sudo cp RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911/wpa_supplicant_hostapd/wpa_supplicant_hostapd-0.8_rtw_r7475.20130812/hostapd/hostapd /usr/sbin/hostapd
sudo cp RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911/wpa_supplicant_hostapd/wpa_supplicant_hostapd-0.8_rtw_r7475.20130812/hostapd/hostapd_cli /usr/sbin/hostapd_cli

echo "Done!"
