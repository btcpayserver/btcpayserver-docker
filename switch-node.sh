#!/bin/bash

set -e

usage() {
    cat <<-END
Usage: switch-node.sh default|bitcoincore

The default and bitcoincore options currently both select Bitcoin Core 31.1.
Use default to follow the implementation selected by the BTCPay Server team.
Use bitcoincore to explicitly select Bitcoin Core.
END
}

node="$1"

case "$node" in
    default|bitcoincore)
        ;;
    *)
        usage
        exit 1
        ;;
esac

if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OS
	BASH_PROFILE_SCRIPT="$HOME/btcpay-env.sh"

else
	# Linux
	BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"
fi

. helpers.sh


BTCPAYGEN_ADDITIONAL_FRAGMENTS="$(remove_fragments "$BTCPAYGEN_ADDITIONAL_FRAGMENTS" "bitcoincore" "bitcoinknots")"
BTCPAYGEN_EXCLUDE_FRAGMENTS="$(remove_fragments "$BTCPAYGEN_EXCLUDE_FRAGMENTS" "bitcoin")"

if [ "$node" != "default" ]; then
    BTCPAYGEN_EXCLUDE_FRAGMENTS="$(add_fragments "$BTCPAYGEN_EXCLUDE_FRAGMENTS" "bitcoin")"
    BTCPAYGEN_ADDITIONAL_FRAGMENTS="$(add_fragments "$BTCPAYGEN_ADDITIONAL_FRAGMENTS" "$node")"
fi

export BTCPAYGEN_ADDITIONAL_FRAGMENTS
export BTCPAYGEN_EXCLUDE_FRAGMENTS

echo "Switching Bitcoin node implementation to $node"
. btcpay-setup.sh -i
