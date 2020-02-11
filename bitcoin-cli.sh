#!/bin/bash

docker exec btcpayserver_bitcoind bitcoin-cli -datadir="/data" "$@"
