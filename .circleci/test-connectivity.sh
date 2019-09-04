#!/bin/bash

while true; do
    if curl -sL -w "%{http_code}\\n" "http://localhost/" -o /dev/null > /dev/null; then
        break
    fi
    sleep 1
done