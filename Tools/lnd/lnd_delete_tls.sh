#!/bin/bash

set -e

read -p "This script will delete LND's TLS certificate, so that's it's recreated on restart. Please keep in mind that you'll need to update external connections to LND that depend on TLS cert. Type 'yes' to confirm you want to proceed`echo $'\n> '`" yn
if [ $yn != "yes" ]; then
	exit 0
fi

docker exec btcpayserver_lnd_bitcoin rm -rf /root/.lnd/tls.cert
docker exec btcpayserver_lnd_bitcoin rm -rf /root/.lnd/tls.key

docker stop btcpayserver_lnd_bitcoin
docker start btcpayserver_lnd_bitcoin

echo "LND TLS certificate recreated"