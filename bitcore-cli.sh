#!/bin/bash

docker exec -ti btcpayserver_bitcored bitcore-cli -datadir="/data" "$@"
