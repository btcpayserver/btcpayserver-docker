#!/bin/bash

docker exec btcpayserver_groestlcoind groestlcoin-cli -datadir="/data" "$@"