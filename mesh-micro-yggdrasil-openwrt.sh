#!/bin/sh
# https://forum.openwrt.org/t/yggdrasil-network-connection/211884
# https://yggdrasil-network.github.io/installation-linux-openwrt.html

install()
{
if [ `opkg list | grep yggdrasil | wc -l` -lt 1 ]; then
   opkg update
   opkg install yggdrasil luci-proto-yggdrasil
fi

# Get some keys to use
basename=`basename $0`
tmp=/tmp/${basename}_$$
touch ${tmp}
chmod 700 ${tmp}
yggdrasil -genconf >> ${tmp}
private_key=`grep PrivateKey ${tmp} | cut -d':' -f2 | cut -d' ' -f2`
public_key=`yggdrasil -publickey -useconffile ${tmp}`
rm ${tmp}

# Gen configs
if [ ! -f /etc/config/network_yggdrasil ]; then
   cp /etc/config/network /etc/config/network_preyggdrasil
fi
uci add network interface
uci rename network.@interface[-1]=ygg0
uci set network.ygg0.proto='yggdrasil'
uci set network.ygg0.private_key=$private_key
uci set network.ygg0.public_key=$public_key
uci set network.ygg0.jumper_enable='0'
uci set network.ygg0.jumper_loglevel='info'
uci set network.ygg0.allocate_listen_addresses='1'
uci set network.ygg0.jumper_autofill_listen_addresses='1'

uci add network yggdrasil_ygg0_interface
uci set network.@yggdrasil_ygg0_interface[0].interface='br-lan'
uci set network.@yggdrasil_ygg0_interface[0].beacon='1'
uci set network.@yggdrasil_ygg0_interface[0].listen='1'

uci commit network

peer $2

if [ ! -f /etc/config/firewall_yggdrasil ]; then
   cp /etc/config/firewall /etc/config/firewall_preyggdrasil
fi
uci add_list firewall.@zone[1].network='ygg0'
uci commit firewall
}

peer()
{
if [ $1 ]; then
   uci add network yggdrasil_ygg0_peer
   uci set network.@yggdrasil_ygg0_peer[-1].address=$1
   uci commit network
fi
}

uninstall()
{
if [ -f /etc/config/network_preyggdrasil ]; then
   mv /etc/config/network_preyggdrasil /etc/config/network
   mv /etc/config/firewall_preyggdrasil /etc/config/firewall
fi

opkg remove yggdrasil luci-proto-yggdrasil
}

if [ $1 -a $1 = 'uninstall' ]; then
   uninstall
elif [ $1 -a $1 = 'peer' ]; then
   peer $2
else
   install
fi
