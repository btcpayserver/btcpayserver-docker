#!/bin/bash

docker exec -ti btcpayserver_elementsd elements-cli -datadir="/data" "$@"
