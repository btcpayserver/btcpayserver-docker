#!/bin/bash -e

set -o pipefail -o errexit

# Please be aware of these important issues:
#
# - Old channel state is toxic and you can loose all your funds, if you or someone
#   else closes a channel based on the backup with old state - and the state changes
#   often! If you publish an old state (say from yesterday's backup) on chain, you
#   WILL LOSE ALL YOUR FUNDS IN A CHANNEL, because the counterparty will publish a
#   revocation key!

if [ "$(id -u)" != "0" ]; then
  printf "\n🚨 This script must be run as root.\n"
  printf "➡️  Use the command 'sudo su -' (include the trailing hypen) and try again.\n\n"
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
  printf "\n"
  echo "ℹ️  Database container is not up and running. Starting BTCPay Server …"
  btcpay_up

  printf "\n"
  dbcontainer=$(docker ps -a -q -f "name=postgres_1")
  if [ -z "$dbcontainer" ]; then
    echo "🚨 Database container could not be started or found."
    exit 1
  fi
fi

printf "\n"
echo "ℹ️  Dumping database …"
{
  docker exec $dbcontainer pg_dumpall -c -U postgres | gzip > $dbdump_path
  echo "✅ Database dump done."
} || {
  echo "🚨 Dumping failed. Please check the error message above."
  exit 1
}

printf "\nℹ️  Stopping BTCPay Server …\n\n"
btcpay_down

printf "\n"
cd $docker_dir
echo "ℹ️  Archiving files in $(pwd)…"

{
  tar \
    --exclude="volumes/backup_datadir" \
    --exclude="volumes/generated_bitcoin_datadir" \
    --exclude="volumes/generated_litecoin_datadir" \
    --exclude="volumes/generated_postgres_datadir" \
    --exclude="volumes/generated_clightning_bitcoin_datadir/_data/lightning-rpc" \
    --exclude="**/logs/*" \
    -cvzf $backup_path $dbdump_name volumes/generated_*
  echo "✅ Archive done."

  if [ ! -z "$BTCPAY_BACKUP_PASSPHRASE" ]; then
    printf "\n"
    echo "🔐 BTCPAY_BACKUP_PASSPHRASE is set, the backup will be encrypted."
    {
      gpg -o "$backup_path.gpg" --batch --yes -c --passphrase "$BTCPAY_BACKUP_PASSPHRASE" $backup_path
      rm $backup_path
      backup_path="$backup_path.gpg"
      echo "✅ Encryption done."
    } || {
      echo "🚨  Encrypting failed. Please check the error message above."
      # do not exit, we need to restart BTCPay Server
    }
  fi
} || {
  echo "🚨  Archiving failed. Please check the error message above."
  # do not exit, we need to restart BTCPay Server
}

printf "\nℹ️  Restarting BTCPay Server …\n\n"

cd -
btcpay_up

printf "\nℹ️  Cleaning up …\n\n"
rm $dbdump_path

printf "✅ Backup done => $backup_path\n\n"
