#!/bin/bash

# This script might look like a good idea. Please be aware of these important issues:
#
# - The backup file is not encrypted and it contains your lightning private keys.
#   Consider encrypting before uploading or using another backup tool like duplicity.
# - Old channel state is toxic and you can loose all your funds, if you or someone
#   else closes a channel based on the backup with old state - and the state changes
#   often! If you publish an old state (say from yesterday's backup) on chain, you
#   WILL LOSE ALL YOUR FUNDS IN A CHANNEL, because the counterparty will publish a
#   revocation key!

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    echo "Use the command 'sudo su -' (include the trailing hypen) and try again"
    exit 1
fi

case "$BACKUP_PROVIDER" in
  "Dropbox")
    if [ -z "$DROPBOX_TOKEN" ]; then
        echo "Set DROPBOX_TOKEN environment variable and try again."
        exit 1
    fi
    ;;

  "SCP")
    if [ -z "$SCP_TARGET" ]; then
        echo "Set SCP_TARGET environment variable and try again."
        exit 1
    fi
    ;;

  *)
    echo "No BACKUP_PROVIDER set. Backing up to local directory."
    ;;
esac

# preparation
volumes_dir=/var/lib/docker/volumes
backup_dir="$volumes_dir/backup_datadir"
filename="backup.tar.gz"
dumpname="postgres.sql"

if [ "$BACKUP_TIMESTAMP" == true ]; then
  timestamp=$(date "+%Y%m%d-%H%M%S")
  filename="$timestamp-$filename"
  dumpname="$timestamp-$dumpname"
fi

backup_path="$backup_dir/_data/${filename}"
dbdump_path="$backup_dir/_data/${dumpname}"

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh

# dump database
echo "Dumping database …"
btcpay_dump_db $dumpname

if [[ "$1" == "--only-db" ]]; then
    tar -cvzf $backup_path $dbdump_path
else
    # stop docker containers, save files and restart
    echo "Stopping BTCPay Server …"
    btcpay_down

    echo "Backing up files …"
    tar --exclude="$backup_dir/*" --exclude="$volumes_dir/generated_bitcoin_datadir/*" --exclude="$volumes_dir/generated_litecoin_datadir/*" --exclude="$volumes_dir/**/logs/*" -cvzf $backup_path $dbdump_path $volumes_dir

    echo "Restarting BTCPay Server …"
    btcpay_up
fi

# post processing
case $BACKUP_PROVIDER in
  "Dropbox")
    echo "Uploading to Dropbox …"
    docker run --name backup --env DROPBOX_TOKEN=$DROPBOX_TOKEN -v backup_datadir:/data jvandrew/btcpay-dropbox:1.0.5 $filename
    echo "Deleting local backup …"
    rm $backup_path
    ;;

  "SCP")
    echo "Uploading via SCP …"
    scp $backup_path $SCP_TARGET
    echo "Deleting local backup …"
    rm $backup_path
    ;;

  *)
    echo "Backed up to $backup_path"
    ;;
esac

# cleanup
rm $dbdump_path

echo "Backup done."
