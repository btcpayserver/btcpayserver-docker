#!/bin/bash
if [[ "$0" = "$BASH_SOURCE" ]]; then
    echo "This script must be sourced \". taproot_bip8_lottrue_switch.sh\"" 
    exit 1
fi

set -e

if [[ "$BTCPAYGEN_ADDITIONAL_FRAGMENTS" =~ "bitcointaprootcc-bip8-lottrue" ]]; then
 read -p "You are already running bitcointaproot.cc BIP8 taproot node release. Type 'bitcoin_core' to change back to the Bitcoin Core release `echo $'\n> '`" yn
 if [ $yn != "bitcoin_core" ]; then
     exit 0
 fi
 export BTCPAYGEN_ADDITIONAL_FRAGMENTS="${BTCPAYGEN_ADDITIONAL_FRAGMENTS//bitcointaprootcc-bip8-lottrue/}"
 export BTCPAYGEN_EXCLUDE_FRAGMENTS="${BTCPAYGEN_EXCLUDE_FRAGMENTS//bitcoin;/}"

  . btcpay-setup.sh -i
  cd Tools  echo "Configured to use Bitcoin Core release."
  exit 0  
fi


echo "This script will swap the Bitcoin Core release with a release provided on https://bitcointaproot.cc signed by LukeDashJr and bitcoinmechanicca@protonmail.com with BIP8 LOT=TRUE taproot activation. Additional details can be found on: https://bitcointaproot.cc/#faq_mainline"

read -p " Type 'bitcointaprootcc-bip8-lottrue' to switch to HTTPS://BITCOINTAPROOT.CC FORK OF BITCOIN CORE.  `echo $'\n> '`" yn
if [ $yn != "bitcointaprootcc-bip8-lottrue" ]; then
    exit 0
fi

export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;bitcointaprootcc-bip8-lottrue"
export BTCPAYGEN_EXCLUDE_FRAGMENTS="$BTCPAYGEN_EXCLUDE_FRAGMENTS;bitcoin;"

. btcpay-setup.sh -i
cd Tools
echo "Configured to use https://bitcointaproot.cc release." 