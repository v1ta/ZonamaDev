#!/bin/bash
#
# rundir.sh - Run all scripts in a directory based on script's name (i.e. myname.d/*)
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Sat Dec 26 15:39:04 EST 2015
#

TAG=$(basename $ME)

HAVEX=false

if xset q > /dev/null 2>&1; then
    HAVEX=true
fi

# Run output through some stuff to make display more useful and capture errors
if [ "X$CHILD_STATUS" = "X" -a "X$1" = "X" ]; then
    export CHILD_STATUS="/tmp/${TAG}-status-$$"
    echo 253 > $CHILD_STATUS
    # TODO do we need to check for ts?
    # apt-get -y install moreutils
    $ME - 2>&1 | ts -s | logger -i -t ${TAG} -s 2>&1
    st=$(<$CHILD_STATUS)
    if [ $st -eq 0 ]; then
	logger -i -t ${TAG} -s "** $ME SUCCESS **"
    else
	logger -i -t ${TAG} -s "** $ME FAILED! STATUS=$st ** ABORT **"
    fi
    exit $st
fi

## Assets Directory
ASSETS_DIR=$(dirname $ME)'/../assets'

# Trap various failures
trap 'echo $? > $CHILD_STATUS;msg "UNEXPECTED EXIT=$?"' 0
trap 'msg "UNEXPECTED SIGNAL SIGHUP!";echo 21 > $CHILD_STATUS' HUP
trap 'msg "UNEXPECTED SIGNAL SIGINT!";echo 22 > $CHILD_STATUS' INT
trap 'msg "UNEXPECTED SIGNAL SIGTERM!";echo 23 > $CHILD_STATUS' TERM

msg() {
    local hd="##"$(echo "$1"|sed 's/./#/g')"##"
    echo -e "$hd\n# $1 #\n$hd"
}

notice() {
    if $HAVEX; then
	notify-send --icon=${ASSETS_DIR}/swgemu_icon.png --expire-time=0 "$1" "$2"
    else
	echo "**NOTICE** $1: $2"
    fi
}

error() {
    msg "ERROR: $1"
    err=251
    if [ "X$2" != "X" ]; then
	err=$2
    fi
    exit $err
}

# We at least made it this far!
echo 252 > $CHILD_STATUS

###################
## CHILD PROCESS ##
###################

msg "START $ME git-tag: "$(cd $(dirname $ME);git describe --always)

cd $(dirname $ME)

for script in ${ME}'.d'/*
do
    msg "Run $script md5:"$(md5sum $script)
    source $script
done

msg "$ME COMPLETE AFTER $SECONDS SECOND(S)"

#############
## Success ##
#############
trap - 0
echo 0 > $CHILD_STATUS
exit 0

# vi:sw=4 ft=sh
