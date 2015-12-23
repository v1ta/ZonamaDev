#!/bin/bash

logger -i -t firstboot "** %0 START"

(set -x
unset UCF_FORCE_CONFFOLD
export UCF_FORCE_CONFFNEW=YES
ucf --purge /boot/grub/menu.lst

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o Dpkg::Options::="--force-confnew" dist-upgrade
apt-get -y install xfce4 xfce4-goodies lightdm eclipse
) 2>&1 | logger -i -t firstboot -s 2>&1

logger -i -t firstboot "** $0 COMPLETE AFTER $SECOND SECOND(S)"

exit 0
