#!/bin/bash

docker exec -ti btcpayserver_feathercoind feathercoin-cli -datadir="/data" "$@"