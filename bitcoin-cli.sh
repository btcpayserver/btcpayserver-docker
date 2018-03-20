#!/bin/bash

docker exec -ti btcpayserver_bitcoind bitcoin-cli -datadir="/data" "$@"
