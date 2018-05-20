#!/bin/bash

set -e

. /etc/profile.d/btcpay-env.sh

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
    if [ "$scriptname" == "build.sh" -o "$scriptname" == "build-pregen.sh" ] ; then
        continue;
    fi
    echo "Adding symlink of $scriptname to /usr/bin"
    chmod +x $scriptname
    rm /usr/bin/$scriptname &> /dev/null
    ln -s "$(pwd)/$scriptname" /usr/bin
done

cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE up -d --remove-orphans
