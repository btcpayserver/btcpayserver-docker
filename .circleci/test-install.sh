#!/bin/bash

set -e

apt-get remove docker-ce
rm -rf /usr/bin/docker
rm -rf /usr/local/bin/docker-compose

cd ../..

[ -d btcpayserver-docker ] || mv project btcpayserver-docker

cd btcpayserver-docker

export BTCPAY_HOST="btcpay.local"
export REVERSEPROXY_DEFAULT_HOST="btcpay.local"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="ltc"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
source ./btcpay-setup.sh -i

timeout 1m bash .circleci/test-connectivity.sh

# Testing scripts are not crashing and installed
btcpay-up.sh
btcpay-down.sh
