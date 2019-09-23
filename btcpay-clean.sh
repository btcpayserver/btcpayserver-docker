#!/bin/bash

docker image prune -af --filter "label!=org.btcpayserver.image=docker-compose-generator"