# Backup & Restore

This guide gets you up to speed with the [Docker deployment](https://docs.btcpayserver.org/Docker/)'s Backup & Restore process.
You will learn about what to keep in mind when doing a backup and how to restore a backup.

[[toc]]

## Remarks and Considerations

The original backups strategy in BTCPay Server still exists and can be found [here](https://docs.btcpayserver.org/Docker/#how-can-i-back-up-my-btcpay-server).
While this documentation covers the [new process](https://github.com/btcpayserver/btcpayserver-docker/pull/641), the old `backup.sh` script still works.

:::warning
BTCPay Server is and will never be responsible for your backup.
Please make sure the backup includes the files and data you want to store.
Also, test the restore process before starting to rely on it.
:::

### Lightning channel backup

Please be aware of this important issue:
Old Lightning channel state is toxic!
You can lose all your funds if you close a channel based on an outdated state — and the state changes often!
If you publish an old state (say from yesterday's backup), you will most likely lose all your funds in the channel because the counterparty might publish a [revocation transaction](https://www.d11n.net/lightning-network-payment-channel-lifecycle.html#what-happens-in-case-of-a-false-close%3F)!

There is a high chance of failure in a disaster recovery scenario, where you may do a backup once per night and need to restore that one backup.

The Lightning channel backup from the `btcpay-backup.sh` script will be sufficient in a migration case, where the shutdown of the old server happens cleanly.
The old server should not be started after the restoration and start of the new server.

:::tip
The Lightning static channel backup should be watched by a script and copied over to a remote server to ensure you always have the latest state available.
We will provide such a script with a future update.
For now, keep the above in mind when restoring from the backup!
:::

## How does the backup work?

The backup process is run with the `btcpay-backup.sh` script.

Log in to your server, switch to the `root` user and type the following:

```bash
# The backup script needs to be run as the root user
sudo su -

# As the other scripts, it is inside the BTCPay base directory
cd $BTCPAY_BASE_DIRECTORY/btcpayserver-docker
./btcpay-backup.sh
```

The backup process needs to be run as `root`.
It will check for and let you know if you have to switch users.

The script will do the following steps:

* Ensure the database container is running
* Make a dump of the database
* Stop BTCPay Server
* Archive the Docker volumes and database dump
  * Excluding the blockchains `blocks` and `chainstate` directories
  * Optional: [Encrypt the archive](#set-a-backup-passphrase)
* Restart BTCPay Server
* Cleanup: Remove temporary files like the database dump

If the backup directory doesn't exist yet, the script will create it.
With these preparations taken, the backup process is now starting.

The script has checks to ensure it either works or fails with a comprehensive error message at every step of the way.
If there are errors, you will be notified like this:

```
🚨 Database container could not be started or found.
```

If everything works smoothly, you will see multiple completed marks in your console.
Whenever the backup has completed successfully, it will state:

```
✅ Backup done => /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz
```

Your BTCPay Server has now finished the backup process.
You must store these backups safely, for instance, by copying them to a remote server.

After making a backup the first time, it is always wise to at least test your backup in a restore scenario.
We will go over the extra options you can set with your backup in the next topic.

### Set a backup passphrase

You can set the `BTCPAY_BACKUP_PASSPHRASE` environment variable for encrypting the backup.
This passphrase will be used by the backup and restore scripts to encrypt and decrypt the backup file.
For the backup script, this would look like the following:

```bash
# Set the passphrase without adding it to the shell history
read -s -p "Enter passphrase: " BTCPAY_BACKUP_PASSPHRASE
export BTCPAY_BACKUP_PASSPHRASE

./btcpay-backup.sh
```

This `BTCPAY_BACKUP_PASSPHRASE` if set, is necessary to be in the [restore process](#how-to-restore) as well.

### Automation by crontab

Here is an example of a crontab script that does a nightly backup at 4:15 AM:

```
SHELL=/bin/bash
PATH=/bin:/usr/sbin:/usr/bin:/usr/local/bin
15 4 * * * /root/BTCPayServer/btcpayserver-docker/btcpay-backup.sh >/dev/null 2>&1
```

You need to set the right `SHELL` and `PATH`, so that the script can run with the correct context.
You might also want to set the `BTCPAY_BACKUP_PASSPHRASE` environment variable.

Also ensure the base path (here `/root/BTCPayServer`) matches the output of `echo $BTCPAY_BASE_DIRECTORY`.

## How to restore?

It's very similar to the `btcpay-backup.sh` process but in reverse.
The `btcpay-restore.sh` script needs to be run with the path to your `backup.tar.gz` file.

First off, open a terminal and type the following as root.
Remember that if you set `BTCPAY_BACKUP_PASSPHRASE` on the backup, you also need to provide it for decryption :

```bash
# The restore script needs to be run as the root user
sudo su -

# As the other scripts, it is inside the BTCPay base directory
cd $BTCPAY_BASE_DIRECTORY/btcpayserver-docker

# Optional: Set the passphrase if you have used one for the backup
read -s -p "Enter passphrase: " BTCPAY_BACKUP_PASSPHRASE
export BTCPAY_BACKUP_PASSPHRASE

# Run the restore script with the full path to the backup file
./btcpay-restore.sh /var/backups/backup.tar.gz.gpg
```

The script will do the following steps:

* Extract (and decrypt) the backup archive
* Stop BTCPay Server
* Restore the Docker volumes
* Start the database container
* Import the database dump
* Restart BTCPay Server
* Cleanup: Remove the temporary restore directory

If the backup file cannot be found in the provided path, the script will exit with an error.

```
🚨 /var/backups/backup.tar.gz.gpg does not exist.
```

Just as the `btcpay-backup.sh` script, the restore will stop at ANY error it may encounter.
If the backup file was created while the `BTCPAY_BACKUP_PASSPHRASE` was set but not used on restoring, the following error would occur:

```
🚨  Decryption failed. Please check the error message above.
```

When the restore has completed, you get the message:

```
✅ Restore done
```

Everything should be up and running again when the restore is complete.
You've successfully restored your BTCPay Server. Congratulations!

:::tip
Always make sure your backup strategy is tested and fits your needs.
No one solution fits all, and we tried to cover the basic cases.
For the latest updates, always feel free to ask on the BTCPay Server community channels.
:::
