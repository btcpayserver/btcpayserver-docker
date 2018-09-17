#!/bin/bash

docker exec -ti --user dash btcpayserver_dashd dash-cli "$@"
