#!/bin/bash

set -e

usage() {
    cat <<-END
Usage: switch-node.sh default|bitcoincore|bitcoinknots

The default Bitcoin node implementation is selected by the BTCPay Server team.
This is currently Bitcoin Core 29.x and is planned to move to Bitcoin Core 31.0 later.
Use bitcoincore or bitcoinknots to explicitly pin your deployment to one of those implementations.
END
}

node="$1"

case "$node" in
    default|bitcoincore|bitcoinknots)
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

remove_fragments() {
    local value="$1"
    local result=""
    local fragment

    value="${value//,/;}"
    IFS=';' read -ra fragments <<< "$value"
    for fragment in "${fragments[@]}"; do
        fragment="${fragment//[[:space:]]/}"
        case "$fragment" in
            ""|bitcoin|bitcoincore|bitcoinknots)
                continue
                ;;
        esac

        if [ -z "$result" ]; then
            result="$fragment"
        else
            result="$result;$fragment"
        fi
    done

    echo "$result"
}

append_fragment() {
    local value="$1"
    local fragment="$2"

    if [ -z "$value" ]; then
        echo "$fragment"
    else
        echo "$value;$fragment"
    fi
}

BTCPAYGEN_ADDITIONAL_FRAGMENTS="$(remove_fragments "$BTCPAYGEN_ADDITIONAL_FRAGMENTS")"
BTCPAYGEN_EXCLUDE_FRAGMENTS="$(remove_fragments "$BTCPAYGEN_EXCLUDE_FRAGMENTS")"

if [ "$node" != "default" ]; then
    BTCPAYGEN_EXCLUDE_FRAGMENTS="$(append_fragment "$BTCPAYGEN_EXCLUDE_FRAGMENTS" "bitcoin")"
    BTCPAYGEN_ADDITIONAL_FRAGMENTS="$(append_fragment "$BTCPAYGEN_ADDITIONAL_FRAGMENTS" "$node")"
fi

export BTCPAYGEN_ADDITIONAL_FRAGMENTS
export BTCPAYGEN_EXCLUDE_FRAGMENTS

echo "Switching Bitcoin node implementation to $node"
. btcpay-setup.sh -i
