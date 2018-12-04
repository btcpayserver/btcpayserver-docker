#!/bin/bash

docker exec -ti btcpayserver_dashd dash-cli -datadir="/data" "$@"
