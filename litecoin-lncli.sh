#!/bin/bash

docker exec btcpayserver_lnd_litecoin lncli --macaroonpath /root/.lnd/admin.macaroon "$@"
