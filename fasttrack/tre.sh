#!/bin/bash
#
# tre.sh - Find TRE files on user's HOST system and scp to the guest

trepath=''
default='/c/SWGEmu'

main() {
    msg "TRE File Copy"

    # Check for default location
    if check_emudir "$default"; then
	if yorn "\n** We found your tre files in ${default} do you want to copy them to the server now?"; then
	    trepath="$default"
	else
	    msg "** ABORTED BY USER **"
	    exit 1
	fi
    else
	echo -e "\n** In order to run the server you must copy required '.tre' files from the client"
	echo -e  "** If you've installed the client on this computer we can copy them for you.\n"

	# TODO do we want to ask?
	#if yorn "Would you like to try and copy the '.tre' files now?"; then
	    ask_emudir
	#fi
    fi

    echo -e "\n** Ok we found your files in $trepath, we will now try and copy them to your guest...\n"

    local sshcfg=$(mktemp)
    trap 'rm -f "'$sshcfg'"' 0

    echo "** Checking to make sure your guest is up..."
    vagrant up > /dev/null 2>&1
    
    echo "** Getting ssh configuration..."
    vagrant ssh-config > $sshcfg || error "Failed to get ssh config, GET HELP!" 11

    echo "** Copying files..."
    ssh -F $sshcfg default mkdir -p Desktop/SWGEmu

    if scp -F $sshcfg "$trepath"/*.tre default:Desktop/SWGEmu; then
	msg "SUCCESS!"
    else
	msg "SCP SEEMS TO HAVE FAILED WITH ERR=$?, GET HELP!?"
    fi

    exit 0
}

ask_emudir() {
    while :
    do
	echo
	read -rp "Where did you install the swgemu client? " n

	local path=$(cygpath ${n//\\/\/})

	#local path="${n//\\/\/}"

	echo "Searching [$path]"

	# Does it look like the right directory?
	if check_emudir "$path"; then
	    # hit the jackpot
	    trepath=$path
	    return 0
	else
	    if yorn "Didn't find the tre files there, do you mind if I search ${path} for them?"; then
		local fn=$(find $path -name $last_tre 2> /dev/null)

		if [ -n "$fn" ]; then
		    path=$(dirname $fn)

		    if check_emudir "$path"; then
			trepath="$path"
			return 0
		    fi
		fi

		if yorn "Still didn't find them, would you like to try another directory?"; then
		    :
		else
		    return 0
		fi
	    else
		return 0
	    fi
	fi
    done
}

check_emudir() {
    local dir=$1
    local cnt=$(ls "$dir"/*.tre 2> /dev/null|wc -l)

    if [ $cnt -eq 0 ]; then
	return 1
    fi

    if [ $cnt -ge ${#trefiles[@]} ]; then
	# TODO check trefiles array
	return 0
    fi

    return 1
}

yorn() {
  if tty -s; then
      echo -n -e "$@ Y\b" > /dev/tty
      read yorn < /dev/tty
      case $yorn in
	[Nn]* ) return 1;;
      esac
  fi
  return 0
}

error() {
    err_msg=$1
    err_code=251
    if [ "X$2" != "X" ]; then
	err_code=$2
    fi

    msg "ERROR WHILE PROCESSING $RUN_STEP: $err_msg ($err_code)"

    exit $err_code
}

msg() {
    local hd="##"$(echo "$1"|sed 's/./#/g')"##"
    echo -e "$hd\n# $1 #\n$hd"
}

declare -a trefiles
trefiles=('bottom.tre' 'data_animation_00.tre' 'data_music_00.tre' 'data_other_00.tre' 'data_sample_00.tre' 'data_sample_01.tre' 'data_sample_02.tre' 'data_sample_03.tre' 'data_sample_04.tre' 'data_skeletal_mesh_00.tre' 'data_skeletal_mesh_01.tre' 'data_sku1_00.tre' 'data_sku1_01.tre' 'data_sku1_02.tre' 'data_sku1_03.tre' 'data_sku1_04.tre' 'data_sku1_05.tre' 'data_sku1_06.tre' 'data_sku1_07.tre' 'data_static_mesh_00.tre' 'data_static_mesh_01.tre' 'data_texture_00.tre' 'data_texture_01.tre' 'data_texture_02.tre' 'data_texture_03.tre' 'data_texture_04.tre' 'data_texture_05.tre' 'data_texture_06.tre' 'data_texture_07.tre' 'default_patch.tre' 'patch_00.tre' 'patch_01.tre' 'patch_02.tre' 'patch_03.tre' 'patch_04.tre' 'patch_05.tre' 'patch_06.tre' 'patch_07.tre' 'patch_08.tre' 'patch_09.tre' 'patch_10.tre' 'patch_11_00.tre' 'patch_11_01.tre' 'patch_11_02.tre' 'patch_11_03.tre' 'patch_12_00.tre' 'patch_13_00.tre' 'patch_14_00.tre' 'patch_sku1_12_00.tre' 'patch_sku1_13_00.tre' 'patch_sku1_14_00.tre')

let "i=${#trefiles[@]} - 1"
last_tre=${trefiles[$i]}

main

# :vi ft=sh sw=4 ai
