#!/bin/bash

docker exec -ti btcpayserver_monacoind monacoin-cli -datadir="/data" "$@"
