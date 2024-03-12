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
if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OS
	BASH_PROFILE_SCRIPT="$HOME/btcpay-env.sh"
else
	# Linux
	BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"
fi

. "$BASH_PROFILE_SCRIPT"

docker_dir=$(docker volume inspect generated_btcpay_datadir --format="{{.Mountpoint}}" | sed -e "s%/volumes/.*%%g")
postgres_dump_name=postgres.sql.gz
btcpay_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
backup_dir="$docker_dir/volumes/backup_datadir/_data"
postgres_dump_path="$docker_dir/$postgres_dump_name"
backup_path="$backup_dir/backup.tar.gz"

# Backup with custom file name and timestamp:
if [ "$BACKUP_TIMESTAMP" == true ]; then
  timestamp=$(date "+%Y%m%d-%H%M%S")
  backup_path="$backup_dir/$timestamp-backup.tar.gz"
fi

# ensure backup dir exists
if [ ! -d "$backup_dir" ]; then
  mkdir -p $backup_dir
fi

cd $btcpay_dir
. helpers.sh

# Postgres database
postgres_container=$(docker ps -a -q -f "name=postgres_1")
if [ -z "$postgres_container" ]; then
  printf "\n"
  echo "ℹ️ Postgres container is not up and running. Starting BTCPay Server …"
  docker volume create generated_postgres_datadir
  docker-compose -f $BTCPAY_DOCKER_COMPOSE up -d postgres

  printf "\n"
  postgres_container=$(docker ps -a -q -f "name=postgres_1")
  if [ -z "$postgres_container" ]; then
    echo "🚨 Postgres container could not be started or found."
    exit 1
  fi
fi

printf "\n"
echo "ℹ️ Dumping Postgres database …"
{
  docker exec $postgres_container pg_dumpall -c -U postgres | gzip > $postgres_dump_path
  echo "✅ Postgres database dump done."
} || {
  echo "🚨 Dumping Postgres database failed. Please check the error message above."
  exit 1
}

# Optional: MariaDB database
mariadb_container=$(docker ps -a -q -f "name=mariadb_1")
if [ ! -z "$mariadb_container" ]; then
  mariadb_dump_name=mariadb.sql.gz
  mariadb_dump_path="$docker_dir/$mariadb_dump_name"
  # MariaDB container exists and is running - dump it
  printf "\n"
  echo "ℹ️ Dumping MariaDB database …"
  {
    docker exec $mariadb_container mysqldump -u root -pwordpressdb -A --add-drop-database | gzip > $mariadb_dump_path
    echo "✅ MariaDB database dump done."
  } || {
    echo "🚨 Dumping MariaDB database failed. Please check the error message above."
    exit 1
  }
fi

# BTCPay Server backup
printf "\nℹ️ Stopping BTCPay Server …\n\n"
btcpay_down

printf "\n"
cd $docker_dir
echo "ℹ️ Archiving files in $(pwd)…"

{
  tar \
    --exclude="volumes/backup_datadir" \
    --exclude="volumes/generated_btcpay_datadir/_data/host_*" \
    --exclude="volumes/generated_bitcoin_datadir/_data" \
    --exclude="volumes/generated_litecoin_datadir/_data" \
    --exclude="volumes/generated_elements_datadir/_data" \
    --exclude="volumes/generated_xmr_data/_data" \
    --exclude="volumes/generated_dogecoin_datadir/_data/blocks" \
    --exclude="volumes/generated_dogecoin_datadir/_data/chainstate" \
    --exclude="volumes/generated_dash_datadir/_data/blocks" \
    --exclude="volumes/generated_dash_datadir/_data/chainstate" \
    --exclude="volumes/generated_dash_datadir/_data/indexes" \
    --exclude="volumes/generated_dash_datadir/_data/debug.log" \
    --exclude="volumes/generated_mariadb_datadir" \
    --exclude="volumes/generated_postgres_datadir" \
    --exclude="volumes/generated_electrumx_datadir" \
    --exclude="volumes/generated_lnd_bitcoin_datadir/_data/data/graph" \
    --exclude="volumes/generated_clightning_bitcoin_datadir/_data/lightning-rpc" \
    --exclude="**/logs/*" \
    -cvzf $backup_path $postgres_dump_name  $mariadb_dump_name volumes/generated_*
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
      printf "\nℹ️  Restarting BTCPay Server …\n\n"
      cd $btcpay_dir
      btcpay_up
      exit 1
    }
  fi
} || {
  echo "🚨 Archiving failed. Please check the error message above."
  printf "\nℹ️ Restarting BTCPay Server …\n\n"
  cd $btcpay_dir
  btcpay_up
  exit 1
}

printf "\nℹ️ Restarting BTCPay Server …\n\n"
cd $btcpay_dir
btcpay_up

printf "\nℹ️ Cleaning up …\n\n"
rm $postgres_dump_path

printf "✅ Backup done => $backup_path\n\n"
