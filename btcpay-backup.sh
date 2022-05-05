#!/bin/bash -e

# Please be aware of these important issues:
#
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

# preparation
docker_dir=$(docker volume inspect generated_btcpay_datadir --format="{{.Mountpoint}}" | sed -e "s%/volumes/.*%%g")
dbdump_name=postgres.sql.gz
btcpay_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
backup_dir="$docker_dir/volumes/backup_datadir/_data"
dbdump_path="$docker_dir/$dbdump_name"
backup_path="$backup_dir/backup.tar.gz"

# ensure backup dir exists
if [ ! -d "$backup_dir" ]; then
  docker volume create backup_datadir
fi

cd $btcpay_dir
. helpers.sh

dbcontainer=$(docker ps -a -q -f "name=postgres_1")
if [ -z "$dbcontainer" ]; then
  echo "Database container is not up and running. Starting BTCPay Server …"
  btcpay_up

  dbcontainer=$(docker ps -a -q -f "name=postgres_1")
  if [ -z "$dbcontainer" ]; then
    echo "Database container could not be started or found."
    exit 1
  fi
fi

echo "Dumping database …"
btcpay_dump_db $dbdump_path

echo "Stopping BTCPay Server …"
btcpay_down

echo "Backing up files …"
cd $docker_dir
tar \
  --exclude="volumes/backup_datadir" \
  --exclude="volumes/generated_postgres_datadir" \
  --exclude="volumes/generated_bitcoin_datadir" \
  --exclude="volumes/generated_litecoin_datadir" \
  --exclude="**/logs/*" \
  -cvzf $backup_path $dbdump_name volumes/generated_*
cd -

echo "Restarting BTCPay Server …"
btcpay_up

echo "Cleaning up …"
rm $dbdump_path

echo "Backup done."
