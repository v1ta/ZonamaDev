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
	    exit 0
	fi
    fi

    if vagrant destroy; then
	:
    else
	echo "** ABORTED BY USER **"
	exit 0
    fi

    date

    time vagrant up

    # Use instructions from README.md
    echo
    echo "*** Manual Steps ***"
    sed -e '1,/^### Manual steps/d' -e '/^###/,$d' README.md

    if yorn "Have you completed these steps?"; then
	package_box
    else
	echo "** When you're ready to package type: ./build.sh package"
	exit 0
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

    local sshcfg=$(mktemp /tmp/build-basebox.XXXXXX)
    trap 'rm -f "'$sshcfg'"' 0

    echo "** Getting ssh configuration..."
    vagrant ssh-config > $sshcfg || error "Failed to get ssh config, GET HELP!" 11

    builder=$(cat .builder 2> /dev/null)

    echo "** Pulling latest greatest ${ZONAMADEV_URL}..."
    if ssh -t -F $sshcfg default "rm -fr ZonamaDev;git clone ${ZONAMADEV_URL}"; then
	:
    else
	msg "git clone ${ZONAMADEV_URL} SEEMS TO HAVE FAILED WITH ERR=$?, fix it and after that try: ./build.sh package"
	exit 1
    fi

    echo "** Executing package prep on guest..."

    if ssh -t -F $sshcfg default "exec sudo ZDUSER=\${USER} ZonamaDev/basebox/scripts/package-prep.sh '$version' '$builder'"; then
	msg "SUCCESS!"
    else
	local st=$?

	# When the server shuts us down ssh looks like it returns 255
	if [ $st -eq 255 ]; then
            :
	else
	    # Anything else was not expected
	    msg "package-prep.sh SEEMS TO HAVE FAILED WITH ERR=$?, fix it and after that try: ./build.sh package"
	    exit 1
	fi
    fi

    # Wait for virtualbox to cleanly exit
    sleep 5

    echo "** Ok now build the package!"

    # TODO - Include a Vagrantfile with hints/metadata?
    if vagrant package; then
	:
    else
	echo "** Something went wrong!?"
	exit 1
    fi

    if [ -f package.box ]; then
	local fn=package-${version}.box
	mv package.box $fn
	ls -lh "$PWD/$fn"
        echo
        # Use instructions from README.md
        sed -e '1,/^### Publish/d' -e '/^###/,$d' -e 's/x\.y\.z/'"${version}"'/g' -e '/```/,/```/s/^/   * /' -e '/```/d' README.md
    else
	echo "** Something strange happened did not get a package.box file!?"
    fi

    exit 0
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
	echo -e "\nNew Version: ${version}\n"
    else
	echo "** ABORTED BY USER **"
	exit 0
    fi
}

msg() {
    local hd="##"$(echo "$1"|sed 's/./#/g')"##"
    echo -e "$hd\n# $1 #\n$hd"
}

error() {
    err_msg=$1
    err_code=251
    if [ "X$2" != "X" ]; then
	err_code=$2
    fi

    msg "ERROR: $err_msg ($err_code)"

    exit $err_code
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

main $@

exit 0
