#!/bin/bash

docker exec btcpayserver_feathercoind feathercoin-cli -datadir="/data" "$@"