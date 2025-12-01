#!/bin/sh
# https://github.com/JonStratton/mesh-micro
# A simple self contained wrapper around batctl

# Defaults and items from the config
ssid=my_mesh
channel=1

install()
{
opkg update
opkg install batctl-full kmod-batman-adv luci-proto-batman-adv

if [ ! -f /etc/config/wireless_prebatmanadv ]; then
   cp /etc/config/wireless /etc/config/wireless_prebatmanadv
fi
uci set wireless.radio0.channel=$channel
uci delete wireless.radio0.disabled
uci delete wireless.default_radio0
uci add wireless wifi-iface
uci rename wireless.@wifi-iface[-1]=mesh0
uci set wireless.mesh0.ssid=$ssid
uci set wireless.mesh0.encryption='none'
uci set wireless.mesh0.device='radio0'
uci set wireless.mesh0.mode='adhoc'
uci set wireless.mesh0.network='nwi_mesh0'
uci set wireless.mesh0.ifname='mesh0'
uci commit wireless

if [ ! -f /etc/config/network_prebatmanadv ]; then
   cp /etc/config/network /etc/config/network_prebatmanadv
fi
uci add network interface
uci rename network.@interface[-1]=bat0
uci set network.bat0.proto='batadv'
uci set network.bat0.gw_mode='client'
uci add network interface
uci rename network.@interface[-1]=nwi_mesh0
uci set network.nwi_mesh0.mtu='2304'
uci set network.nwi_mesh0.proto='batadv_hardif'
uci set network.nwi_mesh0.master='bat0'
uci add network interface
uci rename network.@interface[-1]=bat0_wan
uci set network.bat0_wan.ifname='bat0'
uci set network.bat0_wan.proto='dhcp'
uci commit network

if [ ! -f /etc/config/firewall_premeshmicro ]; then
   cp /etc/config/firewall /etc/config/firewall_prebatmanadv
fi
uci add_list firewall.@zone[1].network='bat0_wan'
uci commit firewall
}

uninstall()
{
if [ -f /etc/config/network_prebatmanadv ]; then
   mv /etc/config/wireless_prebatmanadv /etc/config/wireless
   mv /etc/config/network_prebatmanadv /etc/config/network
   mv /etc/config/firewall_prebatmanadv /etc/config/firewall
fi

opkg remove batctl-full kmod-batman-adv luci-proto-batman-adv
}

if [ $1 -a $1 = 'uninstall' ]; then
   uninstall
else
   install
fi
