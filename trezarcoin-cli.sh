#!/bin/bash

docker exec btcpayserver_trezarcoind trezarcoin-cli -datadir="/data" "$@"