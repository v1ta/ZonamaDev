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
echo ">> Zero swap"
readonly swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
readonly swappart=$(readlink -f /dev/disk/by-uuid/"$swapuuid")
/sbin/swapoff "$swappart"
dd if=/dev/zero of="$swappart" bs=1M > /dev/null 2>&1
echo ">> Make new swap"
/sbin/mkswap -U "$swapuuid" "$swappart"

chown -R vagrant:vagrant ~vagrant

# Clean up any misc stuff in dev's user account
echo ">> Cleanup user files that shouldn't be in the base box image."
(cd ~vagrant; rm -rf .suspend_devsetup .bash* .profile .inputrc .vim* .cache /var/mail/*) 2> /dev/null

# Stop all the noise
service lightdm stop
service vboxadd stop
service mysql stop
service syslog stop

# Make sure VBox service really stops
vbpid=$(cat /var/run/vboxadd-service.pid 2> /dev/null)

[ -n "$vbpid" ] && kill -9 $vbpid

# Cleanup all the logs
find /var/log /etc/machine-id /var/lib/dbus/machine-id -type f | while read fn
do
    echo ">> Zero $fn"
    cp /dev/null "$fn"
done

echo ">> Fill filesystem with 0 bytes to reduce box size"
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

echo ">> Sync disk"
sync; sync

echo "***********************"
echo "** HALT AND POWEROFF **"
echo "***********************"

set -x

halt --force --no-wall --poweroff

echo "** SHOULD NOT BE HERE! GET HELP! **"

exit 1
