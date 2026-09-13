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

# A removed service's stdout and stderr must survive container deletion.
docker run --name btcpay-test-log-orphan \
    --label com.docker.compose.project=generated \
    --label com.docker.compose.service=retired-service \
    --label com.docker.compose.oneoff=False \
    --label com.docker.compose.config-hash=log-archive-test \
    --entrypoint /bin/sh btcpayserver/docker-compose-generator:local \
    -c 'echo archive-stdout-marker; echo archive-stderr-marker >&2'
. ./helpers.sh
(
    archive_test_dir="$(mktemp -d)"
    trap 'rm -f -- "$archive_test_dir/.env" "$archive_test_dir/compose.yaml"; rmdir -- "$archive_test_dir"' EXIT
    cp "$BTCPAY_ENV_FILE" "$archive_test_dir/.env"
    export BTCPAY_ENV_FILE="$archive_test_dir/.env"

    # The generated YAML is elsewhere: logs -p must work without a default file.
    btcpay_archive_logs

    # Neither an unrelated default file nor inherited COMPOSE_FILE may restrict
    # retrieval to configured services or break capture of the orphan's output.
    printf 'invalid: [\n' > "$archive_test_dir/compose.yaml"
    COMPOSE_FILE="$archive_test_dir/compose.yaml" btcpay_archive_logs
)
docker rm btcpay-test-log-orphan
archives=("$BTCPAY_BASE_DIRECTORY"/btcpay-update-logs/update-*.log.gz)
[ "${#archives[@]}" -eq 2 ]
for archive in "${archives[@]}"; do
    gzip -t "$archive"
    gzip -cd "$archive" | grep -F archive-stdout-marker
    gzip -cd "$archive" | grep -F archive-stderr-marker
done

# Test that the installed scripts run without crashing.
btcpay-up.sh
btcpay-down.sh
