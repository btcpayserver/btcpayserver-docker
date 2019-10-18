#!/bin/bash

. /etc/profile.d/btcpay-env.sh

export NEW_HOST="$1"

if [[ "$NEW_HOST" == https:* ]] || [[ "$NEW_HOST" == http:* ]]; then
echo "The domain should not start by http: or https:"
else
export OLD_HOST=`cat $BTCPAY_ENV_FILE | sed -n 's/^BTCPAY_HOST=\(.*\)$/\1/p'`
echo "Changing domain from \"$OLD_HOST\" to \"$NEW_HOST\""

export BTCPAY_HOST="$NEW_HOST"
export ACME_CA_URI="production"
[[ "$OLD_HOST" == "$REVERSEPROXY_DEFAULT_HOST" ]] && export REVERSEPROXY_DEFAULT_HOST="$NEW_HOST"
pushd . > /dev/null
# Modify environment file
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh
btcpay_update_docker_env
btcpay_up
popd > /dev/null
fi