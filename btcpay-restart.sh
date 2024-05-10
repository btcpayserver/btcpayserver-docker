#!/bin/bash

if [[ -z "$BTCPAY_HOST" ]]; then
    echo "BTCPAY_HOST should not be empty"
    return
fi

BASH_PROFILE_SCRIPT="$HOME/btcpay-$BTCPAY_HOST-env.sh"

. ${BASH_PROFILE_SCRIPT}

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh
btcpay_restart
