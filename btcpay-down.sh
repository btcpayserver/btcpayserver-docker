#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OS
	BASH_PROFILE_SCRIPT="$HOME/btcpay-env.sh"

else
	# Linux
	BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"
fi

. "$BASH_PROFILE_SCRIPT"

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh
btcpay_down