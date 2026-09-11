# Backup & Restore

This guide explains the backup and restore process for the [Docker deployment](https://docs.btcpayserver.org/Docker/).
You will learn what to consider when creating a backup and how to restore one.

[[toc]]

## Remarks and Considerations

The original backup strategy for BTCPay Server still exists and is documented [here](https://docs.btcpayserver.org/Docker/#how-can-i-back-up-my-btcpay-server).
While this guide covers the [new process](https://github.com/btcpayserver/btcpayserver-docker/pull/641), the old `backup.sh` script still works.

:::warning
BTCPay Server is not and will never be responsible for your backups.
Make sure your backups include all the files and data you want to preserve.
Test that you can restore a backup before relying on your backup strategy.
:::

### Lightning channel backup

Be aware of this important issue: old Lightning channel state is toxic!
You can lose all your funds if you close a channel based on an outdated state — and the state changes often!
If you publish an old state (for example, from yesterday's backup), you will most likely lose all your funds in the channel because the counterparty might publish a [revocation transaction](https://www.d11n.net/lightning-network-payment-channel-lifecycle.html#what-happens-in-case-of-a-false-close%3F)!

Disaster recovery is particularly risky if you back up only once per night and then need to restore that backup.

The Lightning channel data captured by the `btcpay-backup.sh` script is sufficient for a planned migration, provided that the old server is shut down cleanly.
Do not start the old server again after restoring and starting the new server.

:::tip
The Lightning static channel backup should be monitored by a script and copied to a remote server so that you always have the latest state available.
We will provide such a script with a future update.
Until then, keep the above in mind when restoring a backup!
:::

## How does the backup work?

The backup process is run using the `btcpay-backup.sh` script.

Log in to your server, switch to the `root` user, and run the following commands:

```bash
# The backup script needs to be run as the root user
sudo su -

# Like the other scripts, it is inside the BTCPay base directory
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
./btcpay-backup.sh
```

The backup script must be run as `root` and will tell you how to switch users if necessary.

The script performs the following steps:

* Ensure the database containers are running and ready
* Dump the databases
* Stop BTCPay Server
* Archive the Docker volumes and database dumps
  * Exclude blockchain data and caches that can be downloaded again
  * Optionally [encrypt the archive](#set-a-backup-passphrase)
* Restart BTCPay Server
* Remove temporary files, such as the database dumps

If the backup directory does not exist yet, the script creates it.

The script validates each step and stops with a clear error if one fails.
For example:

```
🚨 Postgres container could not be started or found.
```

If everything works smoothly, you will see several completion messages in your console.
When an unencrypted backup completes successfully, the final message is:

```
✅ Backup done => /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz
```

When encryption is enabled, the output filename is `backup.tar.gz.gpg` instead.

The backup is now complete.
Store it safely, for instance, by copying it to a remote server.

After creating your first backup, test it by restoring it in a safe environment.
The next section explains how to enable backup encryption.

### Set a backup passphrase

To encrypt a backup, set the `BTCPAY_BACKUP_PASSPHRASE` environment variable.
The backup and restore scripts use this passphrase to encrypt and decrypt the backup file.
The encrypted backup is saved as `backup.tar.gz.gpg`.
For example:

```bash
# Set the passphrase without adding it to the shell history
read -s -p "Enter passphrase: " BTCPAY_BACKUP_PASSPHRASE
export BTCPAY_BACKUP_PASSPHRASE

./btcpay-backup.sh
```

To [restore](#how-to-restore) the encrypted backup, set `BTCPAY_BACKUP_PASSPHRASE` to the same passphrase.

### Automation by crontab

Here is an example crontab entry that runs a nightly backup at 4:15 AM:

```bash
SHELL=/bin/bash
PATH=/bin:/usr/sbin:/usr/bin:/usr/local/bin
15 4 * * * /root/BTCPayServer/btcpayserver-docker/btcpay-backup.sh >/dev/null 2>&1
```

Set the correct `SHELL` and `PATH` so that the script runs in the expected environment.
If the cron job should encrypt backups, also set `BTCPAY_BACKUP_PASSPHRASE` in its environment.

Make sure the base path in the command (here `/root/BTCPayServer`) matches the output of `echo "$BTCPAY_BASE_DIRECTORY"`.

## How to restore?

The restore process is similar to the `btcpay-backup.sh` process, but in reverse.
Run the `btcpay-restore.sh` script with the full path to either an unencrypted `backup.tar.gz` file or an encrypted `backup.tar.gz.gpg` file.

First, open a terminal and switch to the `root` user:

```bash
# The restore script needs to be run as the root user
sudo su -

# Like the other scripts, it is inside the BTCPay base directory
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
```

To restore an unencrypted backup, run:

```bash
./btcpay-restore.sh /var/backups/backup.tar.gz
```

To restore an encrypted backup, set the same passphrase that was used to create it and run:

```bash
read -s -p "Enter passphrase: " BTCPAY_BACKUP_PASSPHRASE
export BTCPAY_BACKUP_PASSPHRASE

./btcpay-restore.sh /var/backups/backup.tar.gz.gpg
```

The script will do the following steps:

* Extract the backup archive (and decrypt it when necessary)
* Stop BTCPay Server
* Restore the Docker volumes
* Start the database containers and wait until they are ready
* Import the database dumps with strict error handling
* Restart BTCPay Server
* Remove the temporary restore directory after a successful restore

If the backup file cannot be found at the provided path, the script exits with an error.
For example:

```
🚨 /var/backups/backup.tar.gz.gpg does not exist.
```

Like the `btcpay-backup.sh` script, the restore script stops at any error it encounters.
If an error occurs after BTCPay Server has been stopped, the containers remain stopped to avoid running against partially restored data.
The temporary restore directory is retained for diagnosis and its path is printed in the error output.
If the passphrase for an encrypted backup is incorrect, the restore fails with the following error:

```
🚨 Decryption or archive extraction failed. Please check the error above.
```

When the restore completes, you will see:

```
✅ Restore done
```

Everything should be up and running again when the restore is complete.
You've successfully restored your BTCPay Server. Congratulations!

:::tip
Always make sure your backup strategy is tested and fits your needs.
No single solution fits every situation; this guide covers the common cases.
For the latest guidance, feel free to ask on the BTCPay Server community channels.
:::

## How to migrate to a new server?

The necessary steps always depend on your setup and infrastructure but as a rough guideline the following steps and considerations will get you through the process.

:::warning
If you have Lightning Network (LN) channels open on your internal node, you need to make sure to **not** restore any old channel state, otherwise your are at the risk of loosing funds. Therefore it is important to shut down BTCPay on the old server immediately after the backup has finished as outlined below.
:::


### Preparation   

#### Temporarily reduce the TTL of your domain:   
Depending on the TTL (time-to-live) of your DNS entries (A-Record) for you BTCPay Server domains/subdomains it makes sense to reduce the TTL a day or a few hours before you want to start the migration. In case anything goes wrong you can quickly switch between new and old server IP addresses. You should set the TTL for the domain/subdomain to some shorter timewindow eg. 600 seconds (10 minutes) or if possible 300 seconds (5 mins). You can do this in at your domain registrar control center.

#### Environment variables:
write down the environment variables you need for the setup on the new server as written in the [Docker installation guide](/Docker/#full-installation-for-technical-users).

```bash
echo $BTCPAY_HOST
echo $NBITCOIN_NETWORK
echo $BTCPAYGEN_CRYPTO1
echo $BTCPAYGEN_ADDITIONAL_FRAGMENTS
echo $BTCPAYGEN_REVERSEPROXY
echo $BTCPAYGEN_LIGHTNING
echo $BTCPAY_ENABLE_SSH
```

:::tip
If you have custom modifications or additional altcoins then do not forget to write down those environment variables too.
:::


#### Prepare the NEW server:  

Install the operating system on the new server/VPS without installing BTCPay, yet. 


### Migration steps

#### On the OLD server:   
- [make the backup](#how-does-the-backup-work)
- stop all containers by running `./btcpay-stop.sh` (this ensures no outdated LN channel state gets restored on the new server)
- copy the backup archive to new server

#### At the domain registrar:   
Change the DNS A-Record of your domains/subdomains to the NEW server IP address and wait 5-10 mins (depending on the TTL)

#### On the NEW server:   
- install BTCPay according to [our Docker installation guide](/Docker/#full-installation-for-technical-users) but with the same environment variable values you wrote down in the preparation steps above
- wait until the installation finished (takes a few minutes) and check if you can access the btcpay interface, you will see that the node is still synching which is fine
- run the [restore process](#how-to-restore) (you can do this even if node not fully synced yet, it will continue after the restore is finished)
- if everything works on the new server you can shutdown and wipe the old server
