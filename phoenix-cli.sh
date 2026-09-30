#!/bin/bash

docker exec phoenixd /phoenix/phoenix-cli --http-password-file /run/secrets/phoenixd_password.pwd "$@"
