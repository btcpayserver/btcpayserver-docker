#!/bin/bash

set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OS
	BASH_PROFILE_SCRIPT="$HOME/btcpay-env.sh"

else
	# Linux
	BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"
fi

. ${BASH_PROFILE_SCRIPT}

if [ ! -z $BTCPAY_DOCKER_COMPOSE ] && [ ! -z $DOWNLOAD_ROOT ] && [ -z $BTCPAYGEN_OLD_PREGEN ]; then 
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/btcpayserver-docker/tree/master#i-deployed-before-btcpay-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    exit
fi

if [[ $BTCPAY_DOCKER_COMPOSE != *docker-compose.generated.yml ]]; then
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/btcpayserver-docker/tree/master#i-deployed-before-btcpay-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    exit
fi

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

if ! ./build.sh; then
    echo "Failed to generate the docker-compose"
    exit 1
fi

if [ "$BTCPAYGEN_OLD_PREGEN" == "true" ]; then
    cp Generated/docker-compose.generated.yml $BTCPAY_DOCKER_COMPOSE
    cp Generated/torrc.tmpl "$(dirname "$BTCPAY_DOCKER_COMPOSE")/torrc.tmpl"
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

. helpers.sh
install_tooling
btcpay_update_docker_env
btcpay_up

set +e
docker image prune -af --filter "label!=org.btcpayserver.image=docker-compose-generator"
