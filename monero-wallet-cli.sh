#!/bin/bash

docker exec -it btcpayserver_monerod monero-wallet-cli "$@"
