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

    if [ ! -f 'config.yml' ]; then
	local cores=$(calc_cores)
	let "ram=(768 * $cores)"
	echo -e "cores: ${cores}\nram: ${ram}" > config.yml
	echo "Setting config.yml to use ${cores} cores for guest and ${ram}m of ram."
    fi

    echo "vagrant up"

    time vagrant up

    if [ $? == 101 ]; then
	echo "** Running vagrant up again after plugin install **"
	time vagrant up
    fi

    sleep 5

    ./tre.sh --auto

    echo "** Now switch to the linux console and follow the directions!"

    exit 0
}

size_ram_osx() {
    sysctl -n hw.memsize
}

size_cores_osx() {
    sysctl -n hw.physicalcpu
}

size_ram_win() {
    wmic memorychip get capacity|awk 'NR > 1 {x = x + $1 } END { print x }'
}

size_cores_win() {
    nproc 2> /dev/null || echo $NUMBER_OF_PROCESSORS
}

size_ram_linux() {
    free -t -b|awk 'NR == 2 { print $2 }'
}

size_cores_linux() {
    nproc
}

calc_cores() {
    case $(uname -s) in
	Darwin ) OS='osx' ;;
	*Linux* ) OS='linux' ;;
	*_NT* ) OS='win';;
	* ) echo "Not sure what OS you are on, guessing Windows"; OS='win';;
    esac

    local total_ram=$(size_ram_$OS)
    local total_cores=$(size_cores_$OS)
    local bycore=0
    local byram=0
    local est_ram=0

    let "byram=($total_ram / 1024 / 1024 / 4 * 3) / 768"
    let "bycore=$total_cores / 4 * 3"
    let "bycore=$bycore - $bycore % 2"

    local cores=$byram

    if [ "$cores" -gt "$bycore" ]; then
	cores=$bycore
    fi

    if [ "$cores" -le "2" ]; then
	cores=0
    fi

    echo $cores
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
