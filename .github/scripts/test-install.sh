#!/bin/bash

set -e

systemctl stop docker.socket
apt-get remove docker-ce
rm -rf /usr/bin/docker
rm -rf /usr/local/bin/docker-compose

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPOSITORY_ROOT"

export BTCPAY_HOST="btcpay.local"
export REVERSEPROXY_DEFAULT_HOST="btcpay.local"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="ltc"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_DOCKER_IMAGE="btcpayserver/docker-compose-generator:local"
source ./btcpay-setup.sh -i

jq -e '
  .requiredRoutes == ["rtl"] and
  .optionalRoutes == ["clightning-rest"] and
  (.fragments | index("bitcoin-clightning") != null)
' Generated/manifest.json > /dev/null

timeout 1m bash .github/scripts/test-connectivity.sh

# A service's stdout and stderr must survive container deletion.
docker run --name btcpay-test-log-container \
    --label com.docker.compose.project=generated \
    --label com.docker.compose.service=btcpayserver \
    --label com.docker.compose.oneoff=False \
    --label com.docker.compose.config-hash=log-archive-test \
    --entrypoint /bin/sh btcpayserver/docker-compose-generator:local \
    -c 'echo archive-stdout-marker; echo archive-stderr-marker >&2'
. ./helpers.sh
btcpay_archive_logs
docker rm btcpay-test-log-container
archives=("$BTCPAY_BASE_DIRECTORY"/btcpay-update-logs/update-*.log.gz)
[ "${#archives[@]}" -eq 1 ]
gzip -cd "${archives[0]}" | grep -F archive-stdout-marker
gzip -cd "${archives[0]}" | grep -F archive-stderr-marker

# Test that the installed scripts run without crashing.
btcpay-up.sh
btcpay-down.sh
