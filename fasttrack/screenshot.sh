#!/bin/bash
#
# screenshot.sh - Take screenshot of linux box's screen and save to ~/Desktop
#
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Mon Jan  2 18:01:22 UTC 2017
#
pushd $(dirname ${BASH_SOURCE[0]}) > /dev/null
ME=$(pwd -P)'/'$(basename ${BASH_SOURCE[0]})
popd > /dev/null

# Calc where we want to save the screen shot
ss="ZonamaDev-ScreenShot-$(date +%s).png"
if [ -d "${HOME}/Desktop" ]; then
    ss="${HOME}/Desktop/${ss}"
fi

# Can we use the vm's uuid?
fast=true
vm_uuid=$(cat "$(dirname '${ME}')/.vagrant/machines/default/virtualbox/id" 2> /dev/null)

if [ -z "${vm_uuid}" ]; then
    fast=false
fi

vbm=$(type -P VBoxManage)

if [ -z "$vbm" ]; then
  vbm="${VBOX_MSI_INSTALL_PATH:-${VBOX_INSTALL_PATH}}/VBoxManage"
fi

if [ ! -x "${vbm}" ]; then
    vbm=''
    fast=false
fi

if $fast; then
    if "${vbm}" list runningvms|fgrep -q "{${vm_uuid}}"; then
        "${vbm}" controlvm "$vm_uuid" screenshotpng "${ss}"
    else
        echo "** Please start the server first with: vagrant up"
        exit 1
    fi
else
    sshcfg=$(mktemp)
    trap "rm -f '${sshcfg}'" 0 1 2 15
    echo '** Getting ssh configuration'
    vagrant ssh-config > "${sshcfg}"

    if [ ! -s "${sshcfg}" ]; then
        echo "** Please start the server first with: vagrant up"
        exit 1
    fi

    echo '** Asking guest to save snapshot'
    ssh -F "${sshcfg}" default "xwd -silent -root -display ':0' | convert - png:-" > "${ss}"
    ret=$?
fi

if [ -s "${ss}" ]; then
    echo "Screenshot saved to: ${ss}"
    exit 0
fi

echo "Screenshot may have failed, ssh returned $ret"

exit 2
