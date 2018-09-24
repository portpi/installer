#!/bin/bash

# Install required packages

sudo apt-get -y update
sudo apt-get -y upgrade

sudo apt-get install -y dnsmasq hostapd

sudo systemctl stop dnsmasq
sudo systemctl stop hostapd

# Configure a static IP

if ! grep -q '^interface wlan0$' /etc/dhcpcd.conf; then
  sudo cat << EOD >> /etc/dhcpcd.conf

# static ip for PortPi
interface wlan0
static ip_address=192.168.3.14/24
nohook wpa_supplicant
EOD
fi

# TODO consider to move this line to the last
sudo service dhcpcd restart

# Configure DHCP server

sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
sudo cat << EOD > /etc/dnsmasq.conf
interface=wlan0
  dhcp-range=192.168.3.15,192.168.3.92,255.255.255.0,24h
EOD

# Configure hostapd

if [ -f /etc/hostapd/hostapd.conf ]; then
  sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak
fi
sudo cat << EOD > /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=PortPi
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=portpi.com
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOD

sudo sed -i 's/^\#\?DAEMON_CONF=.*/DAEMON_CONF="\/etc\/hostapd\/hostapd\.conf"/' /etc/default/hostapd

# Starting services

sudo systemctl start hostapd
sudo systemctl start dnsmasq

# Allow Ethernet internet

sudo sed -i 's/^\#net\.ipv4\.ip_forward=1/net\.ipv4\.ip_forward=1/' /etc/sysctl.conf
sudo iptables -t nat -A  POSTROUTING -o eth0 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
if ! grep -q '/etc/iptables.ipv4.nat' /etc/rc.local; then
  sudo sed -i 's/exit 0/iptables-restore < \/etc\/iptables\.ipv4\.nat/' /etc/rc.local
  echo >> /etc/rc.local
  echo 'exit 0' >> /etc/rc.local
fi

