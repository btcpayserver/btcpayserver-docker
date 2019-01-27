#!/bin/bash

docker exec -ti btcpayserver_bitcoinplusd bitcoinplus-cli -datadir="/data" "$@"