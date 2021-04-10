# mesh-micro
This script is a minimal wrapper around batctl. To Install dependencies

	sudo ./mesh-micro.sh install

To Allow Install to run on boot

	sudo systemctl enable mesh_micro.service

To Uninstall from the system and remove dependencies

	sudo ./mesh-micro.sh install

You can overwrite the defaults by creating “/etc/mesh-micro.conf” (or just modifying the top of the script). Here are is what the defaults would look like in “/etc/mesh-micro.conf”:

	ssid=my_mesh
	channel=2
	wifi_interface=
	internet_interface=
	mesh_type=
	mesh_network=192.168.200.1

Typically, you would only really want to set the ssid and channel to whatever you want your mesh network to be. “wifi_interfaces” will just default to the first interface that starts with “w”, and “internet_interfaces” will default to the first interface starting with “e”. Setting the “wifi_interface” might speed up the starting of the network.
If the config doesn't the host is a client or server(via the mesh_type config value), the mesh-micro.sh will try to ping 8.8.8.8. If the ping fails, it will act as a client. If its successful, it will act as a server. If acting as a server, the script will check the mesh for a dhcp server. If there is none, it will act as a dhcp server.
