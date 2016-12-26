#!/bin/bash
#
# mktarballs.sh - Make the tar balls needed to save manual setup time of the basebox configuration
# 
# Author: Lord Kator <lordkator@swgemu.com>
#
# Created: Mon Dec 26 08:04:55 EST 2016
#
# NOTE: note all files should be placed here, only things changes when you manually configure things
#
# Example to detect config changes, from a fresh basebox after the scripts have run you can do:
#
# vagrant ssh
# touch /tmp/stamp
# << do manual config on the gui >>
# find . -newer /tmp/stamp -depth
#
# Try to choose the core directory where the change happened and make sure you use absolute paths
# from the $HOME directory.
#
# On basebox firstboot all tarballs are extracted to ZDHOME by basebox/scripts/firstboot.d/10tarballs
#

pushd $(dirname ${BASH_SOURCE[0]}) > /dev/null
export ME=$(pwd -P)'/'$(basename ${BASH_SOURCE[0]})
popd > /dev/null

TARBALLDIR=$(dirname $ME)'/../tarballs/'

mktarball() {
    local tarball="${TARBALLDIR}/$1"
    if [ -f "${tarball}" -a ! -f "${tarball}~" ]; then
        echo "Saved old tarball to ${tarball}~"
        mv "${tarball}" "${tarball}~"
    fi
    shift
    echo "Creating ${tarball} with files: $@"
    tar cvzf "${tarball}" "$@"
}

cd $HOME

# default-config.tar.gz - Capture most of the things we care about
mktarball default-config.tar.gz .gnome/apps/ .xscreensaver .config/xfce4/ .config/google-chrome/ Pictures/logo_yellow.png Pictures/3073-starwars-galaxies-002-ilhrq.jpg

echo "*****************************************************************************"
echo "** Don't forget to add the files to git and push them before testing!      **"
echo "**                                                                         **"
echo "** git add -A ${TARBALLDIR};git commit -m 'Updated mktarballs.sh';git push **"
echo "**                                                                         **"
echo "*****************************************************************************"

exit 0
