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

# Modify environment file
sed -i '/^BTCPAY_HOST/d' "$BTCPAY_ENV_FILE"
sed -i '/^ACME_CA_URI/d' "$BTCPAY_ENV_FILE"
echo "BTCPAY_HOST=$BTCPAY_HOST" >> "$BTCPAY_ENV_FILE"
echo "ACME_CA_URI=$ACME_CA_URI" >> "$BTCPAY_ENV_FILE"

cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d
fi
