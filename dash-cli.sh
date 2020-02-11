#!/bin/bash

docker exec btcpayserver_dashd dash-cli -datadir="/data" "$@"
