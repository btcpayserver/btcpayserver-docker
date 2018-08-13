#!/bin/bash

docker exec -ti btcpayserver_lnd_litecoin lncli "$@"
