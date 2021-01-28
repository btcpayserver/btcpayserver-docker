#!/bin/bash

docker exec btcpayserver_bitcoind bitcoin-cli -datadir="/data" -rpcport=43782 "$@"
