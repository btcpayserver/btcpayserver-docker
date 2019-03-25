#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    echo "Use the command 'sudo su -' (include the trailing hypen) and try again"
    exit 1
fi

(return 2>/dev/null) && sourced=1 || sourced=0

if [ $sourced != 1 ]; then
    echo "You forgot the leading '.' followed by a space!"
    echo "Try this format: . ./backup.sh"
    exit 1
fi

if [ -z ${BACKUP_PROVIDER+x} ]; then
    echo "Set BACKUP_PROVIDER environmental variable and try again."
    exit 1
elif [ ${BACKUP_PROVIDER="Dropbox"} ]; then
    btcpay-down.sh
    tar -cvzf $PWD/dropbox-script/backup.tar.gz --exclude='/var/lib/docker/volumes/generated_bitcoin_datadir/*' /var/lib/docker
    btcpay-up.sh
    cd dropbox-script
    ./dropbox-script && rm backup.tar.gz
fi
