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
    if [ -z ${DROPBOX_TOKEN+x} ]; then
        echo "Set DROPBOX_TOKEN environmental variable and try again."
        exit 1
    fi
    if [ ! -d /var/lib/docker/volumes/backup_datadir ]; then
        docker volume create backup_datadir
    fi	
    btcpay-down.sh
    tar --exclude='/var/lib/docker/volumes/backup_datadir/*' --exclude='/var/lib/docker/volumes/generated_bitcoin_datadir/*' -cvzf /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz /var/lib/docker
    btcpay-up.sh
    docker run -v backup_datadir:/data --env DROPBOX_TOKEN=$DROPBOX_TOKEN jvandrew/btcpay-dropbox:1.0.1
fi
