#!/bin/bash

docker exec btcpayserver_monacoind monacoin-cli -datadir="/data" "$@"
