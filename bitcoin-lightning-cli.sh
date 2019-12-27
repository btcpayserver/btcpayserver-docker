#!/bin/bash

docker exec -ti btcpayserver_clightning_bitcoin lightning-cli "$@"
