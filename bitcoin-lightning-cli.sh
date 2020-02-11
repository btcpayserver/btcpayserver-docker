#!/bin/bash

docker exec btcpayserver_clightning_bitcoin lightning-cli --rpc-file /root/.lightning/lightning-rpc "$@"
