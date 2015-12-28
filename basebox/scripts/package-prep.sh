#!/bin/bash
#
# package-prep.sh - Prepare box for vagrant package
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Mon Dec 28 13:54:13 EST 2015
#

version="0.0.0"

if [ -n "$1" ]; then
    version="$1"
fi

echo "$1" > /.swgemudev.version
chmod 644 /.swgemudev.version

# Cleanup apt
apt-get --yes autoremove
apt-get --yes clean

# Remove any dhcp lease files
rm /var/lib/dhcp/*

# Zero sawp
readonly swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
readonly swappart=$(readlink -f /dev/disk/by-uuid/"$swapuuid")
/sbin/swapoff "$swappart"
dd if=/dev/zero of="$swappart" bs=1M
/sbin/mkswap -U "$swapuuid" "$swappart"

chown -R vagrant:vagrant ~vagrant

rm -f ~vagrant/.suspend_devsetup ~vagrant

service lightdm stop
service vboxadd stop
service mysql stop
service syslog stop

vbpid=$(cat /var/run/vboxadd-service.pid 2> /dev/null)

[ -n "$vbpid" ] && kill -9 $vbpid

find /var/log /etc/machine-id /var/lib/dbus/machine-id -type f | while read fn
do
    echo "Zero $f"
    cp /dev/null "$f"
done

dbus-uuidgen > /var/lib/dbus/machine-id

echo "Fill filesystem with 0 bytes to reduce box size"
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

echo "Sync disk"
sync; sync

echo "** HALTING **"

set -x

halt --force --no-wall --poweroff

echo "** SHOULD NOT BE HERE!! **"

exit 1
