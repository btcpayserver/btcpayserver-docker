#!/bin/bash

set -e

: "${BTCPAYGEN_DOCKER_IMAGE:=btcpayserver/docker-compose-generator}"
if [ "$BTCPAYGEN_DOCKER_IMAGE" == "btcpayserver/docker-compose-generator:local" ]
then
    docker build docker-compose-generator -f docker-compose-generator/linuxamd64.Dockerfile --tag $BTCPAYGEN_DOCKER_IMAGE
else
    set +e
    docker pull $BTCPAYGEN_DOCKER_IMAGE
    docker rmi $(docker images btcpayserver/docker-compose-generator --format "{{.Tag}};{{.ID}}" | grep "^<none>" | cut -f2 -d ';') > /dev/null 2>&1
    set -e
fi

# This script will run docker-compose-generator in a container to generate the yml files
docker run -v "$(pwd)/Generated:/app/Generated" \
           -v "$(pwd)/docker-compose-generator/docker-fragments:/app/docker-fragments" \
           -v "$(pwd)/docker-compose-generator/crypto-definitions.json:/app/crypto-definitions.json" \
           -e "BTCPAYGEN_CRYPTO1=$BTCPAYGEN_CRYPTO1" \
           -e "BTCPAYGEN_CRYPTO2=$BTCPAYGEN_CRYPTO2" \
           -e "BTCPAYGEN_CRYPTO3=$BTCPAYGEN_CRYPTO3" \
           -e "BTCPAYGEN_CRYPTO4=$BTCPAYGEN_CRYPTO4" \
           -e "BTCPAYGEN_CRYPTO5=$BTCPAYGEN_CRYPTO5" \
           -e "BTCPAYGEN_CRYPTO6=$BTCPAYGEN_CRYPTO6" \
           -e "BTCPAYGEN_CRYPTO7=$BTCPAYGEN_CRYPTO7" \
           -e "BTCPAYGEN_CRYPTO8=$BTCPAYGEN_CRYPTO8" \
           -e "BTCPAYGEN_CRYPTO9=$BTCPAYGEN_CRYPTO9" \
           -e "BTCPAYGEN_REVERSEPROXY=$BTCPAYGEN_REVERSEPROXY" \
           -e "BTCPAYGEN_ADDITIONAL_FRAGMENTS=$BTCPAYGEN_ADDITIONAL_FRAGMENTS" \
           -e "BTCPAYGEN_EXCLUDE_FRAGMENTS=$BTCPAYGEN_EXCLUDE_FRAGMENTS" \
           -e "BTCPAYGEN_LIGHTNING=$BTCPAYGEN_LIGHTNING" \
           -e "BTCPAYGEN_SUBNAME=$BTCPAYGEN_SUBNAME" \
           -e "BTCPAY_HOST_SSHAUTHORIZEDKEYS=$BTCPAY_HOST_SSHAUTHORIZEDKEYS" \
           --rm $BTCPAYGEN_DOCKER_IMAGE

if [ "$BTCPAYGEN_REVERSEPROXY" == "nginx" ]; then
    cp Production/nginx.tmpl Generated/nginx.tmpl
fi

[[ -f "Generated/pull-images.sh" ]] && chmod +x Generated/pull-images.sh
[[ -f "Generated/save-images.sh" ]] && chmod +x Generated/save-images.sh

if [ "$BTCPAYGEN_REVERSEPROXY" == "traefik" ]; then
    cp Traefik/traefik.toml Generated/traefik.toml
    :> Generated/acme.json
    chmod 600 Generated/acme.json
fi
