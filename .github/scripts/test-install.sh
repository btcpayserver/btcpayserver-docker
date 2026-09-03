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
source ./btcpay-setup.sh -i

timeout 1m bash .github/scripts/test-connectivity.sh

# Test that the installed scripts run without crashing.
btcpay-up.sh
dotnet tool install --tool-path /tmp/dotnet-tools dotnet-stack
docker cp /tmp/dotnet-tools/dotnet-stack generated_nbxplorer_1:/tmp/dotnet-stack
btcpay-down.sh &
down_pid=$!

sleep 15
echo "NBXplorer state while shutdown is pending:"
docker inspect generated_nbxplorer_1 --format '{{json .State}}' || true
docker top generated_nbxplorer_1 -eo pid,ppid,stat,wchan:32,comm,args || true
docker exec generated_nbxplorer_1 /tmp/dotnet-stack report -p 1 || true
docker logs --since 30s generated_nbxplorer_1 || true
echo "PostgreSQL activity while NBXplorer shutdown is pending:"
docker exec generated_postgres_1 psql -U postgres -d postgres -x -c \
  "SELECT pid, datname, application_name, state, wait_event_type, wait_event, now() - query_start AS age, query FROM pg_stat_activity WHERE application_name ILIKE '%nbx%' OR datname LIKE 'nbxplorer%';" || true

wait "$down_pid"
