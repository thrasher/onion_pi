#!/bin/bash

echo "Building hostapd from sources for the RTL8188 chip used in common Raspberry Pi USB WiFi adapters"

if [ ! -e RTL8188C_8192C_USB_linux_v4.0.2_9000.20130911.zip ] ; then
  echo "RTL8188 source file was not found, please download it to $PWD"
  echo "download manually from here: http://www.realtek.com.tw/downloads/downloadsView.aspx?Langid=1&PNid=21&PFid=48&Level=5&Conn=4&DownTypeID=3&GetDown=false&Downloads=true"
  echo "search the page for the 'RTL8188CUS' linux driver"
  read -p "Press [Enter] key to continue, or Ctrl-C to abort"
fi

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
