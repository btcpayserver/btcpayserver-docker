#!/bin/bash

. /etc/profile.d/btcpay-env.sh

export NEW_HOST="$1"

if [[ ! "$NEW_HOST" =~ ^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$ ]]; then
    echo "The domain must be a valid domain name without a protocol." >&2
    exit 1
fi

OLD_HOST="$(sed -n 's/^BTCPAY_HOST=\(.*\)$/\1/p' "$BTCPAY_ENV_FILE")"
export OLD_HOST
echo "Changing domain from \"$OLD_HOST\" to \"$NEW_HOST\""

export BTCPAY_HOST="$NEW_HOST"
export ACME_CA_URI="production"
[[ "$OLD_HOST" == "$REVERSEPROXY_DEFAULT_HOST" ]] && export REVERSEPROXY_DEFAULT_HOST="$NEW_HOST"
pushd . > /dev/null
# Modify environment file
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker" || exit
. helpers.sh
btcpay_update_docker_env
btcpay_up
popd > /dev/null || exit
