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
  .secrets == [] and
  (.fragments | index("opt-add-tor") == null) and
  (.fragments | index("bitcoin-clightning") != null)
' Generated/manifest.json > /dev/null

timeout 1m bash .github/scripts/test-connectivity.sh

# Setup's default CVE-2026-98432 filter must drop TCP that carries IP options, and only that.
python3 - <<'EOF'
import socket, subprocess

def connects(options):
    s = socket.socket()
    s.settimeout(5)
    if options:
        s.setsockopt(socket.IPPROTO_IP, socket.IP_OPTIONS, bytes([7, 7, 4, 0, 0, 0, 0, 0]))
    try:
        s.connect(("127.0.0.1", 80))
        return True
    except OSError:
        return False
    finally:
        s.close()

assert connects(False), "a plain connection to nginx failed"
assert not connects(True), "a connection carrying IP options was not dropped"
assert subprocess.run(["ping", "-R", "-c", "1", "-W", "2", "127.0.0.1"], capture_output=True).returncode == 0, "ping with IP options was dropped"
EOF

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
