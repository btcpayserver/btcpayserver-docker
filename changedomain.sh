#!/bin/bash

. /etc/profile.d/btcpay-env.sh

export NEW_HOST="$1"

if [[ "$NEW_HOST" == https:* ]] || [[ "$NEW_HOST" == http:* ]]; then
echo "The domain should not start by http: or https:"
else
export OLD_HOST=`cat $BTCPAY_ENV_FILE | sed -n 's/^BTCPAY_HOST=\(.*\)$/\1/p'`
echo "Changing domain from \"$OLD_HOST\" to \"$NEW_HOST\""

export BTCPAY_HOST="$NEW_HOST"
export ACME_CA_URI="https://acme-v01.api.letsencrypt.org/directory"

ORIGINAL_DIRECTORY="$(pwd)"
# Modify environment file
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh
btcpay_update_docker_env
cd "$ORIGINAL_DIRECTORY"

cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d -t "${COMPOSE_HTTP_TIMEOUT:-180}"
fi
