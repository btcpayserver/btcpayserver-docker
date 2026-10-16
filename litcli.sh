#!/bin/bash

. /etc/profile.d/btcpay-env.sh

docker exec btcpayserver_litd litcli \
    --basedir="/lit/.lit/" \
    --network="$NBITCOIN_NETWORK" \
    "$@"

# Example usage: . ./bitcoin-litcli.sh status
