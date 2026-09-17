# Backup and Restore

This guide explains the backup and restore process for the [Docker deployment](https://docs.btcpayserver.org/Docker/).
You will learn what to consider when creating a backup and how to restore one.

[[toc]]

## Remarks and Considerations

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

`btcpay-backup.sh` restarts the stack after taking its snapshot, so the archive
alone cannot guarantee frozen Lightning state for a planned migration. Do not
use it as the sole migration procedure for an active Lightning node. Follow the
implementation-specific migration and static-channel-backup guidance, keep the
old node from changing after the final migration snapshot, and never run both
the old and restored nodes.

Copy backups and implementation-specific static channel backups to protected
remote storage. Keep the warning above in mind whenever restoring a Lightning
deployment.

## Create a Backup

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
* Archive the Docker volumes, generated secrets, and database dumps
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

To [restore](#restore-a-backup) the encrypted backup, set `BTCPAY_BACKUP_PASSPHRASE` to the same passphrase.

### Automation by crontab

Here is an example crontab entry that runs a nightly backup at 4:15 AM:

```bash
SHELL=/bin/bash
PATH=/bin:/usr/sbin:/usr/bin:/usr/local/bin
MAILTO=admin@example.com
15 4 * * * /root/BTCPayServer/btcpayserver-docker/btcpay-backup.sh
```

Set the correct `SHELL` and `PATH` so that the script runs in the expected environment.
If the cron job should encrypt backups, also set `BTCPAY_BACKUP_PASSPHRASE` in its environment.
Configure working mail delivery for `MAILTO`, or connect the job to another
monitoring system that reports failures.

Make sure the base path in the command (here `/root/BTCPayServer`) matches the output of `echo "$BTCPAY_BASE_DIRECTORY"`.

Each run replaces the same local `backup.tar.gz` or `backup.tar.gz.gpg` file.
The backup script does not provide retention or an off-host copy. Monitor the
cron result and use a separate, tested process to copy each successful archive
to protected off-host storage with the required retention.

## Restore a Backup

The restore process is similar to the `btcpay-backup.sh` process, but in reverse.
Run the `btcpay-restore.sh` script with the full path to either an unencrypted `backup.tar.gz` file or an encrypted `backup.tar.gz.gpg` file.

First, open a terminal and switch to the `root` user:

```bash
# The restore script needs to be run as the root user
sudo su -

# Like the other scripts, it is inside the BTCPay base directory
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
```

The archive is not a complete deployment profile. Before restoring, prepare a
compatible checkout and run setup with the intended network, chains, Lightning
implementation, and fragments. Restore requires the saved environment profile,
generated Compose file, and `generated_btcpay_datadir` Docker volume to exist.

Standard backups contain generated secrets. Restore refuses to overwrite an
existing `secrets/` path. Stop the prepared target, move that directory aside,
and retain it until the restore is verified:

```bash
btcpay-down.sh
mv "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker/secrets" \
  "$BTCPAY_BASE_DIRECTORY/secrets.before-restore"
```

Do not merge old and restored secret directories.

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
* Restore generated secrets when the backup contains them, failing without overwriting when the destination already exists
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

When the restore script completes, you will see:

```
✅ Restore done
```

This message confirms that the restore steps and Compose startup completed; it
does not prove application health, public HTTPS, chain synchronization, or
Lightning state. Follow the [troubleshooting checks](./troubleshooting.md),
verify the expected services and public hostname, and inspect synchronization
before accepting payments.

:::tip
Always make sure your backup strategy is tested and fits your needs.
No single solution fits every situation; this guide covers the common cases.
For the latest guidance, feel free to ask on the BTCPay Server community channels.
:::
