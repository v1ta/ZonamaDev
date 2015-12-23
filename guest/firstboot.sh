#!/bin/bash

logger -i -t firstboot "** %0 START"

(set -x
unset UCF_FORCE_CONFFOLD
export UCF_FORCE_CONFFNEW=YES
ucf --purge /boot/grub/menu.lst

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o Dpkg::Options::="--force-confnew" dist-upgrade
apt-get -y install dkms build-essential linux-headers-$(uname -r) xfce4 xfce4-goodies lightdm eclipse
apt-get -y autoremove

echo "** Install Google Chrome"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list
apt-get update
apt-get -y install google-chrome-stable

set +x
echo "** Apply Patches"
for i in $(dirname ${BASH_SOURCE[0]})'/patches/'*
do
    echo "** Apply patch $i"
    (cd /;patch -p0 -Nft) < "$i"
done

echo "** Unpack Tarballs"
for i in $(dirname ${BASH_SOURCE[0]})'/tarballs/'*
do
    echo "** unpack $i"
    (umask 0;cd $HOME;tar xvf $i)
done

usermod -c "vagrant" vagrant
) 2>&1 | logger -i -t firstboot -s 2>&1

logger -i -t firstboot "** $0 COMPLETE AFTER $SECONDS SECOND(S)"

exit 0
