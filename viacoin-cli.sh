#!/bin/bash

docker exec -ti btcpayserver_viacoind viacoin-cli -datadir="/data" "$@"
