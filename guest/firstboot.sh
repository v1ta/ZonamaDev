#!/bin/bash
#
# firstboot.sh - Run first setup commands inside the guest system
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Wed Dec 23 19:14:02 EST 2015
#

export PACKAGES="dkms build-essential linux-headers-$(uname -r) xfce4 xfce4-goodies lightdm eclipse google-chrome-stable vim vim-doc vim-scripts avahi-daemon ntp ntpdate wget unzip"

pushd $(dirname ${BASH_SOURCE[0]}) > /dev/null
export ME=$(pwd -P)'/'$(basename ${BASH_SOURCE[0]})
popd > /dev/null

if [ "X$FIRSTBOOT_MAGIC" = "X" -a "X$1" = "X" ]; then
    export FIRSTBOOT_MAGIC=magic
    # Switch to an empty vt on console
    chvt 8
    apt-get -y install moreutils | tee /dev/console
    exec $ME - 2>&1 | ts -s | logger -i -t firstboot -s 2>&1 | tee /dev/console
    logger -i -t firstboot -s "** FAILED TO EXEC: $ME ** ABORT **"
    exit 11
fi

## Should be magic from here on.. :-)
export EXTRAS=$(egrep -hv '^#' extras ~vagrant/extras $(dirname $ME)/extras|sort -u|tr '\n' '\40' 2> /dev/null)

msg() {
    local hd="##"$(echo "$1"|sed 's/./#/g')"##"
    echo -e "$hd\n# $1 #\n$hd"
}

msg "START $ME (git: "$(cd $(dirname $ME);git describe --always)" md5:"$(md5sum $ME)")"

msg "Unpack Tarballs"

for i in $(dirname $ME)'/tarballs/'*
do
    msg "unpack $i"
    (umask 0;cd ~vagrant;tar xpvf $i)
done

msg "Customize system"

usermod -c "vagrant" vagrant

msg "Update Packages"

# Add Googles's chrome repo to sources
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Make sure we don't prompt with confusing things
unset UCF_FORCE_CONFFOLD
export UCF_FORCE_CONFFNEW=YES
ucf --purge /boot/grub/menu.lst

export DEBIAN_FRONTEND=noninteractive

# Trap various failures
trap 'msg "UNEXPECTED EXIT!"' 0
trap 'msg "UNEXPECTED SIGNAL SIGHUP!";exit 21' HUP
trap 'msg "UNEXPECTED SIGNAL SIGINT!";exit 22' INT
trap 'msg "UNEXPECTED SIGNAL SIGTERM!";exit 23' TERM
# exit if anything returns error
set -e

# Get latest repo locations
apt-get update

# Upgrade whatever we can
apt-get -y -o Dpkg::Options::="--force-confnew" dist-upgrade

msg "Install Packages"

echo ">> PACKAGES: $PACKAGES $EXTRAS"

apt-get -y install $PACKAGES $EXTRAS

apt-get -y autoremove

systemctl set-default -f multi-user.target

msg "Apply Patches"

for i in $(dirname ${BASH_SOURCE[0]})'/patches/'*
do
    msg "Apply patch $i"
    if (cd /;exec patch --verbose -p0 -Nft) < "$i"; then
	msg "Patch $i SUCCESS"
    else
	msg "Patch $i failed! ret=$?"
	exit 12
    fi
done

chown -R vagrant:vagrant ~vagrant

logger -i -t firstboot -s "** $0 COMPLETE AFTER $SECONDS SECOND(S)"

trap - 0

exit 0
