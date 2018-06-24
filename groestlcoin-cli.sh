#!/bin/bash

docker exec -ti btcpayserver_groestlcoind groestlcoin-cli -datadir="/data" "$@"