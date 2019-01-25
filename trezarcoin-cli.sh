#!/bin/bash

docker exec -ti btcpayserver_trezarcoind trezarcoin-cli -datadir="/data" "$@"