#!/bin/bash

pushd . > /dev/null
cd "$(dirname "$BTCPAY_ENV_FILE")"
docker-compose -f $BTCPAY_DOCKER_COMPOSE run --rm ndlc "$@"
popd > /dev/null
