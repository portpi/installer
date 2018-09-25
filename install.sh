#!/bin/bash

# Install Git and NodeJS first
# It will run apt-get update

curl -sL https://deb.nodesource.com/setup_8.x | bash
apt-get install -y git nodejs

# Install required packages

apt-get install -y dnsmasq hostapd

systemctl stop dnsmasq
systemctl stop hostapd

# Configure a static IP

if ! grep -q '^interface wlan0$' /etc/dhcpcd.conf; then
  cat << EOD >> /etc/dhcpcd.conf

# static ip for PortPi
interface wlan0
static ip_address=192.168.3.14/24
nohook wpa_supplicant
EOD
fi

# TODO consider to move this line to the last
service dhcpcd restart

# Configure DHCP server

mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
cat << EOD > /etc/dnsmasq.conf
interface=wlan0
  dhcp-range=192.168.3.15,192.168.3.92,255.255.255.0,24h
EOD

# Configure hostapd

if [ -f /etc/hostapd/hostapd.conf ]; then
  mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak
fi
cat << EOD > /etc/hostapd/hostapd.conf
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

sed -i 's/^\#\?DAEMON_CONF=.*/DAEMON_CONF="\/etc\/hostapd\/hostapd\.conf"/' /etc/default/hostapd

# Starting services

systemctl start hostapd
systemctl start dnsmasq

# Allow Ethernet internet

sed -i 's/^\#net\.ipv4\.ip_forward=1/net\.ipv4\.ip_forward=1/' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables-save > /etc/iptables.ipv4.nat
if ! grep -q '/etc/iptables.ipv4.nat' /etc/rc.local; then
  sed -i 's/exit 0/iptables-restore < \/etc\/iptables\.ipv4\.nat/' /etc/rc.local
  echo >> /etc/rc.local
  echo 'exit 0' >> /etc/rc.local
fi

# Install PortPi

mkdir /home/pi/PortPi
cd /home/pi/PortPi

git clone https://github.com/portpi/server.git
cd server
npm install
cd -

git clone https://github.com/portpi/server-startup.git
cp server-startup/init.d/portpi-server /etc/init.d/
rm -rf server-startup

chown -R pi.pi .

/etc/init.d/portpi-server start
update-rc.d portpi-server defaults

cat << EOD
==================================================

      PortPi is installed successfully!

You can connect by joining AP - PortPi
                          with password portpi.com

Visit http://192.168.3.14:15926/ afterwards.

==================================================
EOD
