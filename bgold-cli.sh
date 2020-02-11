#!/bin/bash

docker exec btcpayserver_bgoldd bgold-cli -datadir="/data" "$@"
