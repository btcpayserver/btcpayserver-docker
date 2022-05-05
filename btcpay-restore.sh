#!/bin/bash -e

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  echo "Use the command 'sudo su -' (include the trailing hypen) and try again"
  exit 1
fi

backup_file=$1
if [ -z "$backup_file" ]; then
  echo "Usage: btcpay-restore.sh /path/to/backup.tar.gz"
  exit 1
fi

if [ ! -f "$backup_file" ]; then
  echo "$backup_file does not exist."
  exit 1
fi

# preparation
docker_dir=$(docker volume inspect generated_btcpay_datadir --format="{{.Mountpoint}}" | sed -e "s%/volumes/.*%%g")
restore_dir="$docker_dir/volumes/backup_datadir/_data/restore"
dbdump_name=postgres.sql.gz
btcpay_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"

# ensure clean restore dir
rm -rf $restore_dir
mkdir -p $restore_dir

echo "Extracting files …"
cd $restore_dir
tar -xvf $backup_file -C $restore_dir

# basic control checks
if [ ! -f "$dbdump_name" ]; then
  echo "$dbdump_name does not exist."
  exit 1
fi

if [ ! -d "volumes" ]; then
  echo "volumes directory does not exist."
  exit 1
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

echo "Restoring database …"
cd $restore_dir
gunzip -c $dbdump_name | docker exec -i $dbcontainer psql -U postgres postgres -a

# echo "Stopping BTCPay Server …"
# btcpay_down

# # TODO All the restore tasks :)

# echo "Restarting BTCPay Server …"
# btcpay_up

echo "Cleaning up …"
rm -rf $restore_dir

echo "Restore done."
