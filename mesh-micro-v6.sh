#!/bin/sh
# https://github.com/JonStratton/mesh-micro
# A simple self contained wrapper around batctl

# Defaults and items from the config
ssid=my_mesh
channel=2
wifi_interface=
internet_interface=
mesh_type=

# Exec config file if exists
if [ -f /etc/mesh-micro.conf ]; then
   . /etc/mesh-micro.conf
fi

# Mesh
mesh_wifi_interface()
{
# https://wiki.archlinux.org/index.php/Ad-hoc_networking
frequency=`expr \( $channel \* 5 \) + 2407`
systemctl stop NetworkManager
ip link set $wifi_interface down
ip link set mtu 1532 dev $wifi_interface
iw $wifi_interface set type ibss
ip link set $wifi_interface up
iw $wifi_interface ibss join $ssid $frequency
batctl if destroy
batctl if add $wifi_interface
}

# Client - No interconnection. Get it from BAT0
mesh_client()
{
echo "Acting as Client"
mesh_wifi_interface
batctl gw_mode client
ip link set bat0 up
}

# Server - Act as a DHCP Server and forward packets
mesh_server()
{
echo "Acting as Server"
mesh_wifi_interface
batctl gw_mode server
ip link set bat0 up

# IP Tables stuff here
sysctl -w net.ipv6.ip_forward=1
ip6tables -t nat -A POSTROUTING -o $internet_interface -j MASQUERADE
ip6tables -A FORWARD -i $internet_interface -o bat0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A FORWARD -i bat0 -o $internet_interface -j ACCEPT
}

stop()
{
default_interfaces
sudo ip link set $wifi_interface down
}

default_interfaces()
{
# Defaults and items from the config
ssid=my_mesh
channel=2
wifi_interface=
internet_interface=
mesh_type=

# Exec config file if exists
if [ -f /etc/mesh-micro.conf ]; then
   . /etc/mesh-micro.conf
fi

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
}

mesh()
{
default_interfaces
# If internet connection, server
if [ -z $mesh_type ]; then
   if [ ! -z $internet_interface ] && [ `ping -c 1 -q 8.8.8.8 -I $internet_interface | grep "1 received" | wc -l` -eq 1 ]; then
      mesh_type='server'
   else
      mesh_type='client'
   fi
fi

if [ $mesh_type = 'server' ]; then
   mesh_server
else
   mesh_client
fi
}

install()
{
sudo apt-get install batctl iw iptables

sudo cp $0 /usr/local/sbin/

sudo sh -c '( echo "[Unit]
Description=Mesh Micro Service
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mesh-micro-v6.sh
ExecStop=/usr/local/sbin/mesh-micro-v6.sh stop
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mesh_micro.service )'

sudo systemctl daemon-reload
#sudo systemctl enable mesh_micro.service
}

uninstall()
{
sudo systemctl stop mesh_micro.service
sudo systemctl disable mesh_micro.service
sudo rm /etc/systemd/system/mesh_micro.service
sudo rm /usr/local/sbin/mesh-micro-v6.sh
}

if [ $1 -a $1 = 'stop' ]; then
   stop
elif [ $1 -a $1 = 'install' ]; then
   install
elif [ $1 -a $1 = 'uninstall' ]; then
   uninstall
else
   mesh
fi
