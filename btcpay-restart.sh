#!/bin/bash

. /etc/profile.d/btcpay-env.sh

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"

# Not in a terminal (e.g. the web UI): detach, so restarting BTCPay can't kill the restart midway
if [ ! -t 1 ] && [ -z "$BTCPAY_RESTART_DETACHED" ]; then
    log="$BTCPAY_BASE_DIRECTORY/btcpay-restart.log"
    install -m 600 /dev/null "$log"
    BTCPAY_RESTART_DETACHED=1 setsid ./btcpay-restart.sh > "$log" 2>&1 < /dev/null &
    tail -n +1 -f --pid=$! "$log" || true
    wait $!
    exit
fi

. helpers.sh
btcpay_restart
