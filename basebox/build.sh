#!/bin/bash
#
# build.sh - Build the base box from scratch
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Fri Jan  1 08:00:39 EST 2016
#
# Depends: ZONAMADEV_URL

version="0.0.0"

source ../common/global.config

main() {
    case $1 in
	help ) echo "$0: Choose build or package" ; exit 1 ;;
	package ) package_box ;;
	build | * ) build_box ;;
    esac
}

build_box() {
    if [ ! -f .builder ]; then
	builder=$(cat .builder 2> /dev/null)

	while [ -z "$builder" ]
	do
	    read -p "What's your name? / Who's your daddy? " builder

	    if [[ $builder =~ .*[[:space:]].* ]]; then
		echo "** Sorry no spaces, just your base handle name please"
		builder=''
	    fi
	done

	echo "$builder" > .builder
    fi

    if [ -f package.box ]; then 
	if yorn "** Do you want to remove the old base box? "; then
	    rm -f package.box
	else
	    echo "** ABORTED BY USER **"
	fi
    fi

    if vagrant destroy; then
	:
    else
	echo "** ABORTED BY USER **"
    fi

    SCREEN=$(type -P screen)

    if [ -n "$SCREEN" ]; then
	mv screenlog.0 screenlog.0-prev > /dev/null 2>&1
	SCREEN="${SCREEN} -L"
    fi

    $SCREEN time vagrant up

    echo
    echo "*** Manual Steps ***"
    echo "** 1) Resize the Virtualbox window to 1280x800"
    echo "** 2) Launch eclipse, set default workspace as ~/workspace and resize it"
    echo "** 2) Close eclipse"
    echo "** 3) Launch chrome and resize it"
    echo "** 4) Close chrome"
    echo

    if yorn "Have you completed these steps?"; then
	package_box
    else
	echo "** When you're ready to package type: ./build.sh package"
	exit 0
    fi
}

get_version() {
    if [ -n "$2" ]; then
	version=$2
    else
	local suggest_version=""

	# Try to guess a good version number
	local prev_version=$(grep config.vm.box_version ../fasttrack/Vagrantfile | tr -d '['"'"'"]' | sed -e 's/.*=[ ]*//' -e 's/;//')

	if [ -n "$prev_version" ]; then
	    echo -e "\nPrevious version: $prev_version\n"

	    local point=$(echo $prev_version | cut -d. -f3)

	    let "point=$point + 1"

	    suggest_version=$(echo $prev_version | sed 's/\.[0-9][0-9]*$/.'$point'/')
	fi

	local suggest=""
	
	if [ -n "$suggest_version" ]; then
	    suggest=" (ENTER for default of '$suggest_version')"
	fi

	read -p "What version do you want to use for this box$suggest? " version

	if [ -z "$version" ]; then
	    version=$suggest_version
	fi
    fi

    # TODO should we check x.y.z format?

    if yorn "\nAre you sure you want to use version [$version] for this box?"; then
	:
    else
	echo "** ABORTED BY USER **"
    fi
}

package_box() {
    get_version

    # Make sure it's up
    echo "** Checking to make sure your guest is up..."
    if vagrant up > /dev/null 2>&1; then
	:
    else
	echo "** Failed to start the box? ret=$?"
	exit 1
    fi

    local sshcfg=$(mktemp)
    trap 'rm -f "'$sshcfg'"' 0

    echo "** Getting ssh configuration..."
    vagrant ssh-config > $sshcfg || error "Failed to get ssh config, GET HELP!" 11

    builder=$(cat .builder 2> /dev/null)

    echo "** Pulling latest greatest ${ZONAMADEV_URL}..."
    if ssh -F $sshcfg default "rm -fr ZonamaDev;git clone ${ZONAMADEV_URL}"; then
	msg "SUCCESS!"
    else
	msg "git clone ${ZONAMADEV_URL} SEEMS TO HAVE FAILED WITH ERR=$?, fix it and after that try: ./build.sh package"
	exit 1
    fi

    echo "** Executing package prep on guest..."

    if ssh -F $sshcfg default "exec sudo ZonamaDev/basebox/scripts/package-prep.sh '$version' '$builder'"; then
	msg "SUCCESS!"
    else
	msg "package-prep.sh SEEMS TO HAVE FAILED WITH ERR=$?, fix it and after that try: ./build.sh package"
	exit 1
    fi

    echo "** Ok now build the package!"

    # TODO - Include a Vagrantfile with hints/metadata?
    if vagrant package; then
	:
    else
	echo "** Something went wrong!?"
	exit 1
    fi

    if [ -f package.box ]; then
	mv package.box package-${version}.box

	ls -l $PWD/package-${version}.box

	echo "Ok upload to atlas, don't forget to set the version to ${version} and release it too!"
    else
	echo "** Something strange happened did not get a package.box file!?"
    fi

    exit 0
}

yorn() {
  if tty -s; then
      echo -n -e "$@ Y\b" > /dev/tty
      read yorn < /dev/tty
      case $yorn in
	[Nn]* ) return 1;;
      esac
  else
      echo "Must have a tty"
      exit 1
  fi

  return 0
}

main

exit 0
