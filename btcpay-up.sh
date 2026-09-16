#!/bin/bash

. /etc/profile.d/btcpay-env.sh

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh
btcpay_up
