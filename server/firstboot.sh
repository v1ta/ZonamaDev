#!/bin/bash
(set -x
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
apt-get -y install virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11
) | logger -t firstboot
