#!/bin/bash

docker build -t btcpayserver/docker-compose-generator "$(pwd)/docker-compose-generator"
docker run -v "$(pwd)/Production:/app/Production" -v "$(pwd)/Production-NoReverseProxy:/app/Production-NoReverseProxy" --rm btcpayserver/docker-compose-generator