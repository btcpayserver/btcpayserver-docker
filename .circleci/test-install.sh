#!/bin/bash

set -e

cd ..

export BTCPAY_HOST="btcpay.example.local"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="ltc"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
source ./btcpay-setup.sh -i

timeout 10m bash test-connectivity.sh

# Testing scripts are not crashing and installed
btcpay-up.sh
btcpay-update.sh
btcpay-down.sh