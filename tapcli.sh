#!/bin/bash

. /etc/profile.d/btcpay-env.sh

docker exec btcpayserver_litd tapcli \
    --rpcserver=localhost:8443 \
    --tlscertpath=/lit/.lit/tls.cert \
    --macaroonpath="/lit/.tapd/data/$NBITCOIN_NETWORK/admin.macaroon" \
    --network="$NBITCOIN_NETWORK" \
    "$@"

# Example usage: . ./bitcoin-tapcli.sh getinfo
