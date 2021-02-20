#!/bin/sh

# Defaults and items from the config
ssid=my_mesh
channel=2
wifi_interface=
internet_interface=
type=
bat0network=192.168.200.1

# Exec config file if exists
if [ -f /etc/mesh-micro.conf ]; then
   . /etc/mesh-micro.conf
fi

# Mesh
mesh_wifi_interface()
{
# https://wiki.archlinux.org/index.php/Ad-hoc_networking
frequency=`expr \( $channel \* 5 \) + 2407`
sudo systemctl stop NetworkManager
sudo ip link set $wifi_interface down
sudo ip link set mtu 1532 dev $wifi_interface
sudo iw $wifi_interface set type ibss
sudo ip link set $wifi_interface up
sudo iw $wifi_interface ibss join $ssid $frequency HT20
}

# Client - No interconnection. Get it from BAT0
client()
{
echo "Acting as Client"
mesh_wifi_interface
sudo batctl if add $wifi_interface
sudo batctl gw_mode client
sudo ip link set bat0 up
sudo dhclient bat0
}

# Server - Act as a DHCP Server and forward packets
server()
{
echo "Acting as Server"
mesh_wifi_interface
sudo batctl if add $wifi_interface
sudo batctl gw_mode server
sudo ip link set bat0 up

# IP Tables stuff here

# If no dhcp server on bat0... its up to us.
sleep 5
if [ `sudo dhclient -v bat0 2>&1 | grep "No working leases" | wc -l` -eq 1 ]; then
   echo "No DHCP detected. Starting DNSMasq."
   sudo dhclient -r
   sudo ip addr add $bat0network/24 dev bat0
   sudo dnsmasq --interface=bat0 --dhcp-option=3,$bat0network --dhcp-range=${bat0network}00,${bat0network}99,255.255.255.0,24h
fi
}

## Main
if [ -z $wifi_interface ]; then
   wifi_interface=`ls -1 /sys/class/net/ | grep '^w' | head -n 1`
fi

if [ -z $internet_interface ]; then
   internet_interface=`ls -1 /sys/class/net/ | grep '^e' | head -n 1`
fi

# If internet connection, server
if [ -z $type ]; then
   if [ `ping -c 1 -q 8.8.8.8 -I $internet_interface | grep "1 received" | wc -l` -eq 1 ]; then
      type='server'
   else
      type='client'
   fi
fi

if [ $type == 'server' ]; then
   server
else
   client
fi
