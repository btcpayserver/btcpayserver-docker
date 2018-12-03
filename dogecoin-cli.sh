#!/bin/bash

docker exec -ti btcpayserver_dogecoind dogecoin-cli -datadir="/data" "$@"
