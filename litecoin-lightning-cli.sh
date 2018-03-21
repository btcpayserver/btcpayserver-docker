#!/bin/bash

docker exec -ti btcpayserver_clightning_litecoin lightning-cli "$@"
