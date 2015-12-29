#!/bin/bash
#
# package-prep.sh - Prepare box for vagrant package
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Mon Dec 28 13:54:13 EST 2015
#

cd ~vagrant

if [ $# -ne 2 -o -n "$1" -o -n "$2" ]; then
    echo -e "Usage: $0 {version} {builder_name}\n\t{version} - Basebox version x.y.z (e.g. 0.0.3, 0.0.9 or 1.2.3)\n\t{builder_name} - Who is building this box (e.g lordkator, scurby, darthvaderdev)"
    exit 1
fi

# Check for valid version string
if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    version="$1"
else
    echo "Invalid version string ($1), please use x.y.z where x/y/z = 1 to 3 numeric digits"
    exit 2
fi

builder_name="$2"

#########################
## Verify system state ##
#########################

if [ ! -f .firstboot.ran ]; then
    echo "** It doesn't look like firstboot completed successfully!"
    echo "** PACKAGE ABORTED **"
    exit 3
fi

if [ ! -d workspace/.metadata/.plugins/org.eclipse.ui.intro ]; then
    echo "** Please launch eclipse and make sure to select workspace, resize and exit"
    echo "** PACKAGE ABORTED **"
    exit 4
fi

###############################
## Check eclipse window size ##
###############################
eclipse_width=$(sed -n '/IDEWindow/s/.*width="\([0-9]*\)".*/\1/p' workspace/.metadata/.plugins/org.eclipse.e4.workbench/workbench.xmi)
eclipse_height=$(sed -n '/IDEWindow/s/.*height="\([0-9]*\)".*/\1/p' workspace/.metadata/.plugins/org.eclipse.e4.workbench/workbench.xmi)

if [ $eclipse_width -lt 1280 -o $eclipse_height -lt 720 ]; then
    echo "** Eclipse reports IDE window size as ${eclipse_width}x${eclipse_height}"
    echo "** Please resize to 1280x720 or more"
    echo "** DO NOT MAXIMIZE, RESIZE THE WINDOW SO THE BOTTOM PANEL IS AVAILABLE TO AVOID CONFUSING PEOPLE"
    exit 5
fi

##############################
## Check chrome window size ##
##############################
for i in work_area_bottom work_area_left work_area_right work_area_top; do eval chrome_$i=$(sed -n "s/.*\d34${i}\d34:\([0-9]*\).*/\1/p" .config/google-chrome/Default/Preferences); done

let "chrome_width=${chrome_work_area_right} - ${chrome_work_area_left}"
let "chrome_height=${chrome_work_area_bottom} - ${chrome_work_area_top}"

if [ $chrome_width -lt 1280 -o $chrome_height -lt 720 ]; then
    echo "** Chrome reports browser window size as ${chrome_width}x${chrome_height}"
    echo "** Please resize to 1280x720 or more"
    echo "** DO NOT MAXIMIZE, RESIZE THE WINDOW SO THE BOTTOM PANEL IS AVAILABLE TO AVOID CONFUSING PEOPLE"
    exit 6
fi

###############
## Clean apt ##
###############
apt-get --yes autoremove
apt-get --yes clean

########################
## Remove DHCP leases ##
########################
rm /var/lib/dhcp/*

###############
## Zero Swap ##
###############
echo ">> Zero swap"
readonly swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
readonly swappart=$(readlink -f /dev/disk/by-uuid/"$swapuuid")
/sbin/swapoff "$swappart"
dd if=/dev/zero of="$swappart" bs=1M > /dev/null 2>&1
echo ">> Make new swap"
/sbin/mkswap -U "$swapuuid" "$swappart"

#####################
## Fix permissions ##
#####################
chown -R vagrant:vagrant ~vagrant

###################################################
## Clean up any misc stuff in dev's user account ##
###################################################
echo ">> Cleanup user files that shouldn't be in the base box image."
(
    cd ~vagrant
    rm -rf .suspend_devsetup .bash* .profile .inputrc .vim* .cache /var/mail/* .ssh/id_rsa*
    sed -e '/ vagrant$/p' -e 'd' -i .ssh/authorized_keys
) 2> /dev/null

########################
## Stop all the noise ##
########################
service lightdm stop
service vboxadd stop
service mysql stop
service syslog stop


# Make sure VBox service really stops
vbpid=$(cat /var/run/vboxadd-service.pid 2> /dev/null)

[ -n "$vbpid" ] && kill -9 $vbpid

##########################
## Cleanup all the logs ##
##########################
find /var/log /etc/machine-id /var/lib/dbus/machine-id -type f | while read fn
do
    echo ">> Zero $fn"
    cp /dev/null "$fn"
done

###########################################################
## Fill disk free space with zeros to aid in compression ##
###########################################################
echo ">> Fill filesystem with 0 bytes to reduce box size"
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

#################################
## Save version and build info ##
#################################
echo "$version" > /.swgemudev.version
chmod 644 /.swgemudev.version
echo '{ "build_timestamp": '$(date -u +'%s, "build_datetime": "%Y-%m-%dT%H:%M:%SZ"')', "builder_name": "'$builder_name'" }' | tee /.swgemudev.builinfo.json | python -m json.tool

# Wait for sync to disk
echo ">> Sync disk"
sync; sync

##############
## SUCCESS! ##
##############
echo "***********************"
echo "** HALT AND POWEROFF **"
echo "***********************"

set -x

halt --force --no-wall --poweroff

# these aren't the droids you're looking for...
echo "** SHOULD NOT BE HERE! GET HELP! **"

exit 1
