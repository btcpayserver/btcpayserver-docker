#!/bin/bash

set -e

. /etc/profile.d/btcpay-env.sh

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

if ! [ -f "/etc/docker/daemon.json" ]; then
echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" > /etc/docker/daemon.json
echo "Setting limited log files in /etc/docker/daemon.json"
fi

. ./build.sh
if [ "$BTCPAYGEN_OLD_PREGEN" == "true" ]; then
    cp Generated/docker-compose.generated.yml $BTCPAY_DOCKER_COMPOSE
fi

if ! grep -Fxq "export COMPOSE_HTTP_TIMEOUT=\"180\"" "/etc/profile.d/btcpay-env.sh"; then
    echo "export COMPOSE_HTTP_TIMEOUT=\"180\"" >> /etc/profile.d/btcpay-env.sh
    export COMPOSE_HTTP_TIMEOUT=180
    echo "Adding COMPOSE_HTTP_TIMEOUT=180 in btcpay-env.sh"
fi

. helpers.sh
install_tooling
btcpay_update_docker_env

cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE up -d --remove-orphans -t "${COMPOSE_HTTP_TIMEOUT:-180}"
