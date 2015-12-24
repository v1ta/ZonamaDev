#!/bin/bash
#
# firstboot.sh - Run first setup commands inside the guest system
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Wed Dec 23 19:14:02 EST 2015
#


pushd $(dirname ${BASH_SOURCE[0]}) > /dev/null
export ME=$(pwd -P)$(basename ${BASH_SOURCE[0]})
popd > /dev/null

(
    msg() {
	local hd = "+-"$(echo "$1"|sed 's/./-/g')"-+"
	echo -e "$hd\n| $1 |\n$hd"
    }

    msg "START $ME"

    unset UCF_FORCE_CONFFOLD
    export UCF_FORCE_CONFFNEW=YES
    ucf --purge /boot/grub/menu.lst

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y -o Dpkg::Options::="--force-confnew" dist-upgrade
    apt-get -y install dkms build-essential linux-headers-$(uname -r) xfce4 xfce4-goodies lightdm eclipse
    apt-get -y autoremove

    msg "Install Google Chrome"

    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list
    apt-get update
    apt-get -y install google-chrome-stable

    msg "Apply Patches"

    for i in $(dirname ${BASH_SOURCE[0]})'/patches/'*
    do
	msg "Apply patch $i"
	(cd /;patch -p0 -Nft) < "$i"
    done

    msg "Unpack Tarballs"

    for i in $(dirname $ME)'/tarballs/'*
    do
	msg "unpack $i"
	(umask 0;cd $HOME;tar xvf $i)
    done

    msg "Cusomize system"

    usermod -c "vagrant" vagrant

) 2>&1 | logger -i -t firstboot -s 2>&1

logger -i -t firstboot "** $0 COMPLETE AFTER $SECONDS SECOND(S)"

exit 0
