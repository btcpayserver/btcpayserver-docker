#!/bin/bash

docker exec btcpayserver_dogecoind dogecoin-cli -datadir="/data" "$@"
