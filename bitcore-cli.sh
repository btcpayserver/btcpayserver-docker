#!/bin/bash

docker exec btcpayserver_bitcored bitcore-cli -datadir="/data" "$@"
