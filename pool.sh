#!/bin/bash

. /etc/profile.d/btcpay-env.sh

docker exec btcpayserver_litd pool \
    --rpcserver=localhost:8443 \
    --tlscertpath=/lit/.lit/tls.cert \
    --macaroonpath="/lit/.pool/$NBITCOIN_NETWORK/pool.macaroon" \
    --network="$NBITCOIN_NETWORK" \
    "$@"

# Example usage: . ./bitcoin-pool.sh getinfo
