#!/bin/bash

set -e

. /etc/profile.d/btcpay-env.sh

if [ ! -z $BTCPAY_DOCKER_COMPOSE ] && [ ! -z $DOWNLOAD_ROOT ] && [ -z $BTCPAYGEN_OLD_PREGEN ]; then 
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/btcpayserver-docker/tree/master#i-deployed-before-btcpay-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    exit
fi

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"  
git pull --force

if [[ $BTCPAY_DOCKER_COMPOSE == *docker-compose.generated.yml ]]; then
    # Generate the docker compose in BTCPAY_DOCKER_COMPOSE
    . ./build.sh
    if [ "$BTCPAYGEN_OLD_PREGEN" == "true" ]; then
        cp Generated/docker-compose.generated.yml $BTCPAY_DOCKER_COMPOSE
    fi
fi

for scriptname in *.sh; do
    if [ "$scriptname" == "build.sh" ] || \
       [ "$scriptname" == "build-pregen.sh" ] || \
       [ "$scriptname" == "btcpay-setclocale.sh" ]; then
        continue;
    fi
    echo "Adding symlink of $scriptname to /usr/bin"
    chmod +x $scriptname
    [ -e /usr/bin/$scriptname ] && rm /usr/bin/$scriptname
    ln -s "$(pwd)/$scriptname" /usr/bin
done

cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE up -d --remove-orphans
