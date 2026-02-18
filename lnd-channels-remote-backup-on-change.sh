#!/bin/bash

#  This script is inspired by Alex Bosworth's idea to automate static channels backup (SCB) on local disk
#  https://gist.github.com/alexbosworth/2c5e185aedbdac45a03655b709e255a3
#  However one more step is required to instantly backup the latest SCB on a remote server (off-site) in case of LND server crash.
#  This script will copy SCB to remote server(s) and/or cloud storage(s) of your choice.
  

lnd_channel_backup="/var/lib/docker/volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/mainnet/channel.backup"
key="/root/.ssh/lnd_backup"

# You need provide your remote server credentials and rclone remote name below after copying btcserver ssh key to remote servers 
# and/or configuring rclone accordingly.
# You can add as many remote servers and clouds as you want by adding extra variables and modifying the script

remote_server1="YOUR_REMOTE_SERVER_USER_NAME@YOUR_REMOTE_SERVER_IP:~/btcpayserver/"
cloud1="YOUR_RCLONE_REMOTE:btcpayserver/"

while true; do
    /usr/bin/inotifywait -r -e modify,attrib,close_write,move,create,delete ${lnd_channel_backup}
    /usr/bin/rsync -az -e "ssh -i ${key}" ${lnd_channel_backup} ${remote_server1}
    /usr/bin/rclone sync ${lnd_channel_backup} ${cloud1} --config /root/.config/rclone/rclone.conf
done
