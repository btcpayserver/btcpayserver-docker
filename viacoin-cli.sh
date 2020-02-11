#!/bin/bash

docker exec btcpayserver_viacoind viacoin-cli -datadir="/data" "$@"
