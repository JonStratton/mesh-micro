#!/bin/sh
# https://openwrt.org/docs/guide-user/additional-software/extroot_configuration

if [ `opkg list | grep kmod-usb-storage | wc -l` -lt 1 ]; then
   opkg update
   opkg install block-mount kmod-fs-ext4 e2fsprogs parted kmod-usb-storage
fi

if [ ! $1 ]; then
   echo "Call with a disk. Exiting. See /dev/sd?: "
   ls -1 /dev/sd?
   exit;
fi

if [ ! -e $1 ]; then
   echo "$1 does not exist. Exiting."
   exit;
fi

DISK=$1
parted -s ${DISK} -- mklabel gpt mkpart extroot 2048s -2048s
DEVICE="${DISK}1"
mkfs.ext4 -L extroot ${DEVICE}
 
eval $(block info ${DEVICE} | grep -o -e 'UUID="\S*"')
eval $(block info | grep -o -e 'MOUNT="\S*/overlay"')
uci -q delete fstab.extroot
uci set fstab.extroot="mount"
uci set fstab.extroot.uuid="${UUID}"
uci set fstab.extroot.target="${MOUNT}"
uci commit fstab
 
ORIG="$(block info | sed -n -e '/MOUNT="\S*\/overlay"/s/:\s.*$//p')"
uci -q delete fstab.rwm
uci set fstab.rwm="mount"
uci set fstab.rwm.device="${ORIG}"
uci set fstab.rwm.target="/rwm"
uci commit fstab
 
mount ${DEVICE} /mnt
tar -C ${MOUNT} -cvf - . | tar -C /mnt -xf -
 
echo "Done. Now reboot"
