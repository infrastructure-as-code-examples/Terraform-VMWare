#!/bin/bash

set -eou pipefail

ROOT_PATH=$1
DOMAIN=$2
REVERSE_IPV4_SUBNET=$3
IPV4_SUBNET_ADDRESS=$4
IPV4_NETMASK_LENGTH=$5

sed "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" $ROOT_PATH/config/bind/named_template.conf > $ROOT_PATH/config/bind/named.conf

if [[ $(uname -s) == 'Linux' ]]; then
  sed -i "s/REVERSE_SUBNET_PLACEHOLDER/$REVERSE_IPV4_SUBNET/g" $ROOT_PATH/config/bind/named.conf
  sed -i "s/SUBNET_ADDRESS_PLACEHOLDER/$IPV4_SUBNET_ADDRESS/g" $ROOT_PATH/config/bind/named.conf
  sed -i "s/NETMASK_LENGTH_PLACEHOLDER/$IPV4_NETMASK_LENGTH/g" $ROOT_PATH/config/bind/named.conf
else
  # Mac :-(  Still better than Powershell or MSDOS Command Prompt
  sed -i '' "s/REVERSE_SUBNET_PLACEHOLDER/$REVERSE_IPV4_SUBNET/g" $ROOT_PATH/config/bind/named.conf
  sed -i '' "s/SUBNET_ADDRESS_PLACEHOLDER/$IPV4_SUBNET_ADDRESS/g" $ROOT_PATH/config/bind/named.conf
  sed -i '' "s/NETMASK_LENGTH_PLACEHOLDER/$IPV4_NETMASK_LENGTH/g" $ROOT_PATH/config/bind/named.conf
fi



