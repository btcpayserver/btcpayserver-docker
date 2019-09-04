#!/bin/bash

echo "Trying to connect to btcpayserver..."
while true; do
    if [ "$(curl -sL -w "%{http_code}\\n" "http://localhost/" -o /dev/null)" == "200" ]; then
        echo "Successfully contacted BTCPayServer"
        break
    fi
    sleep 1
done