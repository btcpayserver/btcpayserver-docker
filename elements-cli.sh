#!/bin/bash

docker exec btcpayserver_elementsd_liquid elements-cli -datadir="/data" "$@"
