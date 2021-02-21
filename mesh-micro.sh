#!/bin/sh

# Defaults and items from the config
ssid=my_mesh
channel=2
wifi_interface=
internet_interface=
type=
bat_network=192.168.200.1

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
sudo batctl if destroy
sudo batctl if add $wifi_interface
}

# Client - No interconnection. Get it from BAT0
client()
{
echo "Acting as Client"
mesh_wifi_interface
sudo batctl gw_mode client
sudo ip link set bat0 up

sudo dhclient bat0
}

# Server - Act as a DHCP Server and forward packets
server()
{
echo "Acting as Server"
mesh_wifi_interface
sudo batctl gw_mode server
sudo ip link set bat0 up

# IP Tables stuff here
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o $internet_interface -j MASQUERADE
sudo iptables -A FORWARD -i $internet_interface -o bat0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i bat0 -o $internet_interface -j ACCEPT

# If no dhcp server on bat0... its up to us.
sleep 5
if [ `sudo dhclient -v bat0 2>&1 | grep "No working leases" | wc -l` -eq 1 ]; then
   echo "No DHCP detected. Starting DNSMasq."
   sudo dhclient -r
   sudo ip addr add $bat_network/24 dev bat0
   sudo dnsmasq --interface=bat0 --dhcp-option=3,$bat_network --dhcp-range=${bat_network}00,${bat_network}99,255.255.255.0,24h
fi
}

# Wait for wifi
while [ -z "$wifi_interface" -o ! -e /sys/class/net/$wifi_interface ]; do
   echo "Sleeping 5 for Wifi Interface $wifi_interface"
   sleep 5
   if [ -z "$wifi_interface" ]; then
      wifi_interface=`ls -1 /sys/class/net/ | grep '^w' | head -n 1`
   fi
done

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

if [ $type = 'server' ]; then
   server
else
   client
fi