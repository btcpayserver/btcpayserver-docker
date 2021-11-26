#!/bin/bash

############################################################################################################
# HINT: You can put this script in a cronjob so your deployment can automatically stay current with master #
############################################################################################################

# TODO This script was only tested on Linux. Other OSes may need adjustments.

# Stop on errors
set -e


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root after running \"sudo su -\""
   exit 1
fi

# Navigate to the dir this file is at
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Go to the parent dir of btcpayserver-docker
cd ../../..

echo "Resetting after a potential previous run..."
rm -rf btcpayserver

echo "Cloning using HTTPS so we fetch anonymously and don't run into any potential SSH/pubkey issues..."
git clone https://github.com/btcpayserver/btcpayserver.git --depth=1

cd btcpayserver

echo "Building a new docker image from source..."
docker build -f amd64.Dockerfile -t btcpayserver/btcpayserver:master .

echo "Moving on to the docker stuff..."
cd ../btcpayserver-docker

echo "Copying the 2 fragment YMLs..."
cp ./contrib/UsingMasterBranch/*.custom.yml ./docker-compose-generator/docker-fragments/

echo "Enabling the 2 fragments..."
[[ $BTCPAYGEN_ADDITIONAL_FRAGMENTS =~ .*opt-add-cheatmode.custom.* ]] && echo "Fragment 'opt-add-cheatmode.custom' was already added." || export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-cheatmode.custom"
[[ $BTCPAYGEN_ADDITIONAL_FRAGMENTS =~ .*opt-master-branch.custom.* ]] && echo "Fragment 'opt-master-branch.custom' was already added." || export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-master-branch.custom"

echo "Setting the image to the one we just built..."
export BTCPAY_IMAGE="btcpayserver/btcpayserver:master"

echo "Updating BTCPay deployment to the latest version (might be needed to work with the master branch)..."
./btcpay-update.sh

echo "Applying the new config..."
. btcpay-setup.sh -i

echo "Making sure we're up and running..."
./btcpay-up.sh