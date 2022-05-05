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

volumes_dir=/var/lib/docker/volumes
restore_dir="$volumes_dir/backup_datadir/_data/restore"

mkdir -p $restore_dir
tar -xvf $backup_file -C $restore_dir
