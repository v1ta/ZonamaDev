#!/bin/bash
#
# firstboot.sh - Run first setup commands inside the guest system
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Wed Dec 23 19:14:02 EST 2015
#

export PACKAGES="dkms build-essential linux-headers-$(uname -r) xfce4 xfce4-goodies lightdm zenity xsel mysql-server mysql-workbench gdb autoconf automake autotools-dev libdb-dev liblua5.1-0-dev libmysqlclient-dev libssl-dev gdb gccxml clang openjdk-7-jre google-chrome-stable vim vim-doc vim-scripts avahi-daemon ntp ntpdate wget unzip"
export ECLIPSE_URL="http://eclipse.bluemix.net/packages/mars.1/data/eclipse-cpp-mars-1-linux-gtk-x86_64.tar.gz"

#################################################
## NO USER CONFIGURABLE PARTS BELOW THIS BLOCK ##
#################################################

###############################################################################################
## Do not meddle in the affairs of Dragons, for you are crunchy and taste good with ketchup! ##
###############################################################################################

pushd $(dirname ${BASH_SOURCE[0]}) > /dev/null
export ME=$(pwd -P)'/'$(basename ${BASH_SOURCE[0]})
popd > /dev/null

# Have we ran before?
if [ -f ~vagrant/.firstboot.ran ]; then
    logger -i -t firstboot -s "** ALREADY RAN, REMOVE ~vagrant/.firstboot.ran TO FORCE RE-RUN **"
    exit 0
fi

date +%s > ~vagrant/.suspend_devsetup

# Run output through some stuff to make display more useful and capture errors
if [ "X$FIRSTBOOT_STATUS" = "X" -a "X$1" = "X" ]; then
    export FIRSTBOOT_STATUS="/tmp/firstboot-status-$$"
    echo 253 > $FIRSTBOOT_STATUS
    # Switch to an empty vt on console
    chvt 8
    apt-get -y install moreutils | tee /dev/console
    $ME - 2>&1 | ts -s | logger -i -t firstboot -s 2>&1 | tee /dev/console
    st=$(<$FIRSTBOOT_STATUS)
    if [ $st -eq 0 ]; then
	logger -i -t firstboot -s "** $ME SUCCESS **"
    else
	logger -i -t firstboot -s "** $ME FAILED! STATUS=$st ** ABORT **"
    fi
    exit $st
fi

###################
## CHILD PROCESS ##
###################

# We at least made it this far!
echo 252 > $FIRSTBOOT_STATUS

# Trap various failures
trap 'echo $? > $FIRSTBOOT_STATUS;msg "UNEXPECTED EXIT=$?"' 0
trap 'msg "UNEXPECTED SIGNAL SIGHUP!";echo 21 > $FIRSTBOOT_STATUS' HUP
trap 'msg "UNEXPECTED SIGNAL SIGINT!";echo 22 > $FIRSTBOOT_STATUS' INT
trap 'msg "UNEXPECTED SIGNAL SIGTERM!";echo 23 > $FIRSTBOOT_STATUS' TERM

# Figure out if user gave us extra packages to install
export EXTRAS=$(egrep -hv '^#' extras ~vagrant/extras $(dirname $ME)/extras 2> /dev/null|sort -u|tr '\n' '\40')

msg() {
    local hd="##"$(echo "$1"|sed 's/./#/g')"##"
    echo -e "$hd\n# $1 #\n$hd"
}

msg "START $ME (git: "$(cd $(dirname $ME);git describe --always)" md5:"$(md5sum $ME)")"

#####################
## UNPACK TARBALLS ##
#####################
msg "Unpack Tarballs"

for i in $(dirname $ME)'/tarballs/'*
do
    msg "unpack $i"
    (umask 0;cd ~vagrant;tar xpvf $i)
done

######################
## CUSTOMIZE SYSTEM ##
######################
msg "Customize system"

usermod -c "vagrant" vagrant
usermod vagrant -a -G adm

# Add rc.fasttrak
echo -e '## ZonamaDev Boot\n(set +e;cd ~vagrant;(git clone https://github.com/lordkator/ZonamaDev.git || (cd ZonamaDev;git stash;git pull)) 2> /dev/null;ZonamaDev/fasttrack/scripts/rc.fasttrack;exit 0) > /tmp/rc.fasttrack.out 2>&1' >> /etc/rc.local

# Move exit to end (if any)
sed -e '/^exit/{H;d}' -e '${p;x}' -i /etc/rc.local

#################################
## UPDATE AND INSTALL PACKAGES ##
#################################
msg "Update Packages"

# Add Googles's chrome repo to sources
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Make sure we don't prompt with confusing things
unset UCF_FORCE_CONFFOLD
export UCF_FORCE_CONFFNEW=YES
ucf --purge /boot/grub/menu.lst

export DEBIAN_FRONTEND=noninteractive

# opts='-o Dpkg::Options::="--force-confnew" -o APT::Install-Suggests="false" -o Debug::pkgDPkgPM=true --no-install-recommends'
opts='-o Dpkg::Options::="--force-confnew" -o APT::Install-Suggests="false" --no-install-recommends'

set -x
# exit if anything returns error
set -e

# Get latest repo locations
apt-get update

# Upgrade whatever we can
apt-get -y ${opts} dist-upgrade

msg "Install Packages"

echo ">> PACKAGES: $PACKAGES $EXTRAS"

apt-get -y ${opts} install $PACKAGES $EXTRAS

apt-get -y autoremove

apt-get -y clean

systemctl set-default -f multi-user.target
set +x

#####################
## INSTALL ECLIPSE ##
#####################

if [ "X$ECLIPSE_URL" != "X" ]; then
    msg "Install Eclipse from $ECLIPSE_URL"

    pushd ~vagrant
    mkdir Downloads || echo "Created Downloads directory"
    pushd Downloads
    if wget --progress=dot:giga "$ECLIPSE_URL"; then
	:
    else
	echo "** wget returned $?"
	exit $?
    fi

    ECLIPSE_FN=$PWD/$(basename "$ECLIPSE_URL")

    if [ ! -f $ECLIPSE_FN ]; then
	echo "** Can't find downloaded file"
	exit 100
    fi
    popd
    tar xvf $ECLIPSE_FN
    popd
fi

#######################
## APPLY PATCH FILES ##
#######################
msg "Apply Patches"

for i in $(dirname ${BASH_SOURCE[0]})'/patches/'*
do
    msg "Patch $i: APPLY"
    if (cd /;exec patch --verbose -p0 -Nft) < "$i"; then
	msg "Patch $i: SUCCESS"
    else
	st=$?
	if [ $st -eq 1 ]; then
	    msg "Patch $i: WARNING, Returned $st"
	else
	    msg "Patch $i: FAILED! Returned $st"
	    exit 12
	fi
    fi
done

chown -R vagrant:vagrant ~vagrant

logger -i -t firstboot -s "** $0 COMPLETE AFTER $SECONDS SECOND(S)"

#############
## Success ##
#############
(cd $(dirname $ME);date;set -x;uname -a;java -version 2>&1;git describe --always) > ~vagrant/.firstboot.ran
trap - 0
echo 0 > $FIRSTBOOT_STATUS
exit 0
