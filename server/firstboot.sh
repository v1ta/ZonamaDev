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

set +x
for i in $(dirname ${BASH_SOURCE[0]})'/patches/'*
do
    echo "** Apply patch $i"
    (cd /;patch -p0 -Nft) < "$i"
done

usermod -c "vagrant" vagrant
) 2>&1 | logger -i -t firstboot -s 2>&1

logger -i -t firstboot "** $0 COMPLETE AFTER $SECONDS SECOND(S)"

exit 0
