#!/bin/bash

set -e

BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"

. ${BASH_PROFILE_SCRIPT}

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"

if [[ "$1" != "--skip-git-pull" ]]; then
    git pull --force
    exec "btcpay-update.sh" --skip-git-pull
    return
fi

if ! [ -f "/etc/docker/daemon.json" ] && [ -w "/etc/docker" ]; then
    echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" > /etc/docker/daemon.json
    echo "Setting limited log files in /etc/docker/daemon.json"
fi

. helpers.sh

if ! command -v jq > /dev/null 2>&1; then
    echo "jq is required, installing it now..."
    if command -v apt-get > /dev/null 2>&1; then
        apt-get update -qq >/dev/null
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq >/dev/null || {
            DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -qq >/dev/null
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq >/dev/null
        }
    else
        echo "Error: jq is required but could not be installed automatically." >&2
        exit 1
    fi
fi

docker_update

echo "Archiving logs of running containers..."
if ! btcpay_archive_logs; then
    echo "Warning: Failed to archive container logs; continuing with the update." >&2
fi

if ! ./build.sh --setup-ssh --sync-routes; then
    echo "Failed to generate the docker-compose"
    exit 1
fi

if ! grep -Fxq "export COMPOSE_HTTP_TIMEOUT=\"180\"" "$BASH_PROFILE_SCRIPT"; then
    echo "export COMPOSE_HTTP_TIMEOUT=\"180\"" >> "$BASH_PROFILE_SCRIPT"
    export COMPOSE_HTTP_TIMEOUT=180
    echo "Adding COMPOSE_HTTP_TIMEOUT=180 in btcpay-env.sh"
fi

if [[ "$ACME_CA_URI" == "https://acme-v01.api.letsencrypt.org/directory" ]]; then
    original_acme="$ACME_CA_URI"
    export ACME_CA_URI="production"
    echo "Info: Rewriting ACME_CA_URI from $original_acme to $ACME_CA_URI"
fi

if [[ "$ACME_CA_URI" == "https://acme-staging.api.letsencrypt.org/directory" ]]; then
    original_acme="$ACME_CA_URI"
    export ACME_CA_URI="staging"
    echo "Info: Rewriting ACME_CA_URI from $original_acme to $ACME_CA_URI"
fi

install_tooling
btcpay_update_docker_env
btcpay_up
docker kill --signal HUP generated_btcpayserver_1 >/dev/null 2>&1 || true

set +e
if [ "$BTCPAY_UPDATE_CLEAN" == true ]; then
    ./btcpay-clean.sh
fi
exit 0
