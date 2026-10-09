#!/bin/bash

. /etc/profile.d/btcpay-env.sh

docker exec btcpayserver_litd loop \
    --rpcserver=localhost:8443 \
    --tlscertpath=/lit/.lit/tls.cert \
    --macaroonpath="/lit/.loop/$NBITCOIN_NETWORK/loop.macaroon" \
    --network="$NBITCOIN_NETWORK" \
    "$@"

# Example usage: . ./bitcoin-loop.sh getinfo
