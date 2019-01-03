#!/bin/bash

docker exec -ti btcpayserver_clightning_groestlcoin lightning-cli "$@"
