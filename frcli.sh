#!/bin/bash

. /etc/profile.d/btcpay-env.sh

docker exec btcpayserver_litd frcli \
    --rpcserver=localhost:8443 \
    --tlscertpath=/lit/.lit/tls.cert \
    --macaroonpath="/lit/.faraday/$NBITCOIN_NETWORK/faraday.macaroon" \
    --network="$NBITCOIN_NETWORK" \
    "$@"

# Example usage: . ./bitcoin-frcli.sh insights
