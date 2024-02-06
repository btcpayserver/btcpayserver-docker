#!/bin/bash

docker exec -it btcpayserver_lnd_bitcoin lncli --macaroonpath /root/.lnd/admin.macaroon "$@"
