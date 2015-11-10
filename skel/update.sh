#!/bin/bash
echo "force-confdef" >> /etc/dpkg/dpkg.cfg

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
apt-get dist-upgrade --force-yes -y
