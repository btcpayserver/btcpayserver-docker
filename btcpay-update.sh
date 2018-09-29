#!/bin/bash

set -e

. /etc/profile.d/btcpay-env.sh

if [ ! -z $BTCPAY_DOCKER_COMPOSE ] && [ ! -z $DOWNLOAD_ROOT ] && [ -z $BTCPAYGEN_OLD_PREGEN ]; then 
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/btcpayserver-docker/tree/master#i-deployed-before-btcpay-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    exit
fi

if [[ $BTCPAY_DOCKER_COMPOSE != *docker-compose.generated.yml ]]; then
    echo "You seem to use pre generated docker compose, this is now deprecated.
    Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/btcpayserver-docker/tree/master#i-deployed-before-btcpay-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    exit
fi

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"

if [ "$BTCPAYGEN_OLD_PREGEN" == "true" ]; then
     btcpay-down.sh
     for volume in /var/lib/docker/volumes/production_*/_data; do
         volumedest=${volume/production_/generated_}
         echo "Copying $volume to $volumedest"
         [ -d "$volumedest" ] && rm -rf "$volumedest"
         mkdir -p $volumedest
         mv $volume $volumedest
         rm -rf /var/lib/docker/volumes/production_*
     done
     BTCPAYGEN_OLD_PREGEN="false"
     BTCPAY_DOCKER_COMPOSE="$(pwd)/Generated/docker-compose.generated.yml"
     sed -i '/^export BTCPAYGEN_OLD_PREGEN/d' /etc/profile.d/btcpay-env.sh
     sed -i '/^export BTCPAY_DOCKER_COMPOSE/d' /etc/profile.d/btcpay-env.sh
     echo "export BTCPAYGEN_OLD_PREGEN=\"false\"" >> /etc/profile.d/btcpay-env.sh
     echo "export BTCPAY_DOCKER_COMPOSE=\"$BTCPAY_DOCKER_COMPOSE\"" >> /etc/profile.d/btcpay-env.sh
     echo "Your setup has been partially updated, you still need to close your SSH session and run btcpay-update.sh again"
     exit
 fi

git pull --force
. ./build.sh

for scriptname in *.sh; do
    if [ "$scriptname" == "build.sh" ] || \
       [ "$scriptname" == "btcpay-setclocale.sh" ]; then
        continue;
    fi
    echo "Adding symlink of $scriptname to /usr/bin"
    chmod +x $scriptname
    [ -e /usr/bin/$scriptname ] && rm /usr/bin/$scriptname
    ln -s "$(pwd)/$scriptname" /usr/bin
done

cd "`dirname $BTCPAY_ENV_FILE`"
btcpay-up.sh
