#!/bin/bash

docker exec -ti btcpayserver_bgoldd bgold-cli -datadir="/data" "$@"
