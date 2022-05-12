#!/bin/bash -e

set -o pipefail -o errexit

if [ "$(id -u)" != "0" ]; then
  printf "\n🚨 This script must be run as root.\n"
  printf "➡️  Use the command 'sudo su -' (include the trailing hypen) and try again.\n\n"
  exit 1
fi

backup_path=$1
if [ -z "$backup_path" ]; then
  printf "\nℹ️  Usage: btcpay-restore.sh /path/to/backup.tar.gz\n\n"
  exit 1
fi

if [ ! -f "$backup_path" ]; then
  printf "\n🚨 $backup_path does not exist.\n\n"
  exit 1
fi

if [[ "$backup_path" == *.gpg && -z "$BTCPAY_BACKUP_PASSPHRASE" ]]; then
  printf "\n🔐 $backup_path is encrypted. Please provide the passphrase to decrypt it."
  printf "\nℹ️  Usage: BTCPAY_BACKUP_PASSPHRASE=t0pSeCrEt btcpay-restore.sh /path/to/backup.tar.gz.gpg\n\n"
  exit 1
fi

# preparation
docker_dir=$(docker volume inspect generated_btcpay_datadir --format="{{.Mountpoint}}" | sed -e "s%/volumes/.*%%g")
restore_dir="$docker_dir/volumes/backup_datadir/_data/restore"
dbdump_name=postgres.sql.gz
btcpay_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"

# ensure clean restore dir
printf "\nℹ️  Cleaning restore directory $restore_dir …\n\n"
rm -rf $restore_dir
mkdir -p $restore_dir

if [[ "$backup_path" == *.gpg ]]; then
  echo "🔐 Decrypting backup file …"
  {
    gpg -o "${backup_path%.*}" --batch --yes --passphrase "$BTCPAY_BACKUP_PASSPHRASE" -d $backup_path
    rm $backup_path
    backup_path="${backup_path%.*}"
    printf "✅ Decryption done.\n\n"
  } || {
    echo "🚨  Decryption failed. Please check the error message above."
    exit 1
  }
fi

cd $restore_dir
echo "ℹ️  Extracting files in $(pwd) …"
tar -xvf $backup_path -C $restore_dir

# basic control checks
if [ ! -f "$dbdump_name" ]; then
  printf "\n🚨 $dbdump_name does not exist.\n\n"
  exit 1
fi

if [ ! -d "volumes" ]; then
  printf "\n🚨 volumes directory does not exist.\n\n"
  exit 1
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

printf "\nℹ️  Restoring database …"
cd $restore_dir
gunzip -c $dbdump_name | docker exec -i $dbcontainer psql -U postgres postgres -a

# printf "\nℹ️  Stopping BTCPay Server …\n\n"
# btcpay_down

# # TODO All the restore tasks :)

# echo printf "\nℹ️  Restarting BTCPay Server …\n\n"
# btcpay_up

printf "\nℹ️  Cleaning up …\n\n"
rm -rf $restore_dir $backup_path

printf "✅ Restore done\n\n"
