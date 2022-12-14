#!/bin/bash

set +x

if [[ "$0" = "$BASH_SOURCE" ]]; then
    echo "This script must be sourced \". btcpay-teardown.sh\""
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root after running \"sudo su -\""
    return
fi

# Verify we are in right folder. If we are not, let's go in the parent folder of the current docker-compose.
if ! git rev-parse --git-dir &> /dev/null || [ ! -d "Generated" ]; then
    if [[ ! -z $BTCPAY_DOCKER_COMPOSE ]]; then
        cd $(dirname $BTCPAY_DOCKER_COMPOSE)
        cd ..
    fi
    if ! git rev-parse || [[ ! -d "Generated" ]]; then
        echo "You must run this script inside the git repository of btcpayserver-docker"
        return
    fi
fi

printf "\n🚨 Running this script will completely erase the BTCPay Server instance. Do you wish to perform this action?\n\n"

read -p "➡️  Confirm by typing 'YES': " confirm

if [[ "$confirm" != "YES"* ]]; then
  printf "\n😌 Phew, that was close. Aborting uninstall — thanks for keeping your BTCPay Server!\n\n"
  return
else
  printf "\n👋 Sad to see you go. Thanks for using BTCPay Server!\n"
fi

BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"
ORIGINAL_DIRECTORY="$(pwd)"
BTCPAY_BASE_DIRECTORY="$(dirname "$(pwd)")"

printf "\nℹ️  Stopping BTCPay Server and removing related Docker volumes and networks …\n\n"
docker-compose -f $BTCPAY_DOCKER_COMPOSE down -v
docker system prune -f

printf "\nℹ️  Removing BTCPay Server files …\n\n"
cd $BTCPAY_BASE_DIRECTORY
rm -rf $ORIGINAL_DIRECTORY
rm $BASH_PROFILE_SCRIPT $BTCPAY_ENV_FILE

printf "\n✅ Teardown done, successfully uninstalled BTCPay Server!\n\n"
