#!/bin/bash

# run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    echo "Use the command 'sudo su -' and try again"
    exit 1
fi

# generate LND backup ssh key
if [ -f /root/.ssh/lnd_backup ]; then
    echo "Key exists"
else
    echo "Generating SSH key"
    ssh-keygen -o -a 100 -t ed25519 -f /root/.ssh/lnd_backup -N ''
fi

# check and install rsync and inotify
echo "Checking rsync and inotify..."
for pkgs in rsync inotify-tools; do
        if [ $(dpkg -s $pkgs 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
                echo "$pkgs is already installed "
        else
                apt -yy install $pkgs
                echo "Successfully installed $pkgs "
        fi
done

# check and install rclone
echo "Checking rclone..."
if command -v rclone 2>/dev/null -eq 1; then
        echo "rclone is already installed"
else
        curl https://rclone.org/install.sh | bash
        echo "Successfully installed rclone"
fi
