#!/bin/sh

install()
{
# Install deps, but make sure dnsmasq is off
sudo apt-get install batctl dnsmasq iw
sudo systemctl disable dnsmasq.service
sudo systemctl stop dnsmasq.service

sudo cp ./mesh-micro.sh /usr/local/sbin/

sudo sh -c '( echo "[Unit]
Description=Mesh Micro Service
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/sbin/mesh-micro.sh
Restart=on-failure
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mesh_micro.service )'

sudo systemctl daemon-reload
sudo systemctl enable mesh_micro.service
sudo systemctl start mesh_micro.service
}

uninstall()
{
sudo systemctl stop mesh_micro.service
sudo systemctl disable mesh_micro.service
sudo rm /etc/systemd/system/mesh_micro.service
sudo rm /usr/local/sbin/mesh-micro.sh
sudo rm /etc/dnsmasq.d/mesh-micro.conf
}

if [ $1 -a $1 = 'uninstall' ]; then
   uninstall
else
   install
fi
