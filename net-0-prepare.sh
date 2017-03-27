#!/bin/bash -ex

source config.cfg
source functions.sh

echocolor "Enable the OpenStack Newton repository"
sleep 5
apt-get install software-properties-common -y
add-apt-repository cloud-archive:newton -y

sleep 5
echocolor "Upgrade the packages for server"
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

echocolor "Configuring hostname for NETWORK node"
sleep 3
echo "$HOST_NET" > /etc/hostname
hostname -F /etc/hostname

iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost
cat << EOF >> $iphost
127.0.0.1       localhost $HOST_NET
$CTL_MGNT_IP    $HOST_CTL
$COM1_MGNT_IP   $HOST_COM1
$NET_MGNT_IP    $HOST_NET
EOF

sleep 3
echocolor "Config network for Network node"
ifaces=/etc/network/interfaces
test -f $ifaces.orig || cp $ifaces $ifaces.orig
rm $ifaces
touch $ifaces
cat << EOF >> $ifaces
#Dat IP cho $NET_MGNT_IP node

# LOOPBACK NET
auto lo
iface lo inet loopback

# MGNT NETWORK
auto $NET_MGNT_IF
iface $NET_MGNT_IF inet static
address $NET_MGNT_IP
netmask $NETMASK_ADD_MGNT


# EXT NETWORK
auto $NET_EXT_IF
iface $NET_EXT_IF inet static
address $NET_EXT_IP
netmask $NETMASK_ADD_EXT
gateway $GATEWAY_IP_EXT
dns-nameservers 8.8.8.8

EOF

sleep 5
echocolor "Rebooting machine ..."
init 6
#
