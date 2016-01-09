#!/bin/bash
#
# setup.sh - Build the fast track box from the basebox in atlas
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Fri Dec 25 18:50:00 EST 2015
#

if [ -z "$BASH_VERSION" ]; then
    echo "** Please use BASH to run this script **"
    exit 1
fi

main() {
    if [ ! -f Vagrantfile ]; then
	echo "** You must run this from the fasttrack directory, please cd there and type: ./setup.sh"
	exit 1
    fi

    if vagrant login --check; then
	echo "** You're logged in, if you're using a pre-release copy you should make sure you're in the swgemu org **"
    else
	echo "** You're not logged in, if you're trying to use a pre-release box you're going to fail! **"

	until vagrant login --check; do
	    if yorn "** Do you want to login now? Y\b"; then
		vagrant login
	    else
		break
	    fi
	done
    fi

    echo "vagrant up"

    time vagrant up

    if [ $? == 101 ]; then
	echo "** Running vagrant up again after plugin install **"
	time vagrant up
    fi

    sleep 5

    ./tre.sh

    echo "** Now switch to the linux console and follow the directions!"

    exit 0
}

yorn() {
    echo -n -e "$@ Y\b"
    read yorn
    case $yorn in
	[Nn]* ) return 1;;
    esac
    return 0
}

time main

exit 0

# vi: ft=sh sw=4 cursorline cursorcolumn
