#!/bin/bash

docker exec btcpayserver_litecoind litecoin-cli -datadir="/data" "$@"
