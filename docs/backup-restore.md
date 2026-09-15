# Backup and Restore

This guide explains the backup and restore process for the [Docker deployment](https://docs.btcpayserver.org/Docker/).
You will learn what to consider when creating a backup and how to restore one.

[[toc]]

## Remarks and Considerations

This guide covers `btcpay-backup.sh` and `btcpay-restore.sh`.
Use updated versions of both scripts: older restore scripts do not enforce the archive-mode and LND safety checks described here.

> [!WARNING]
> BTCPay Server is not and will never be responsible for your backups.
> Make sure your backups include all the files and data you want to preserve.
> Test that you can restore a backup before relying on your backup strategy.

### Lightning channel backup

Old Lightning channel state is dangerous: broadcasting a revoked state can cause you to lose all funds in that channel.
A nightly snapshot of a channel database must not be treated as current after the node has processed more payments.
For Bitcoin LND using the default bbolt backend, choose the workflow that fits your situation:

| Workflow | Bitcoin LND data in the archive | Source after backup | Channel recovery |
| --- | --- | --- | --- |
| Default / nightly backup | Wallet and static channel backup (`channel.backup`); excludes `data/graph` | Restarted | Manually import the SCB to request peer force closes |
| Planned migration (`--migrate`) | Includes `data/graph` and the other LND data | All BTCPay containers stay stopped | Restore with `--migrate` to preserve open channels from the current state |

Default backups restart the stack after taking their snapshot and do not preserve frozen channel state for a planned migration.
For Bitcoin LND, use the [planned migration workflow](#planned-migration) below; for other Lightning implementations, follow their migration and static-channel-backup guidance.
Keep the old node from changing after the final migration snapshot, and never run both the old and restored nodes.

The `data/graph/<network>` directory contains `channel.db`, including channel state and revocation history, as well as replay-protection and optional watchtower-client databases.
It is not just a routing cache.
Excluding it from nightly backups avoids archiving a potentially large database while services are stopped.
This is a size/downtime versus recovery-capability tradeoff, not a claim that database backups are useless or inherently unsafe.
[Lightning Labs recommends periodic channel-database backups](https://docs.lightning.engineering/lightning-network-tools/lnd/recovery-planning-for-failure#channel-database) as additional material for specialist recovery, without relying on them for ordinary recovery.
The lightweight default omits that additional recovery material; saving an old database is not itself unsafe, but starting LND from stale channel state is.
These scripts currently support only the default and migration workflows above; they do not provide a routine `--include-lnd-db` option.
Do not schedule `--migrate` as a substitute for periodic database archival: it intentionally leaves the source stopped.

These SCB recovery instructions apply to Bitcoin LND, not Core Lightning.
Core Lightning's existing database backup behavior is unchanged; restoring old Core Lightning state also requires care and is not made safe by the default LND workflow.

> [!WARNING]
> Default backups made since [September 24, 2022](https://github.com/btcpayserver/btcpayserver-docker/commit/7d4f4cea6b42f873c72b99dd20a5eb05a1842dae) also exclude Bitcoin LND's channel database.
> Earlier documentation overstated their migration capability: a clean shutdown does not compensate for missing channel data.
> These archives remain supported for [SCB disaster recovery](#recovering-lnd-with-a-static-channel-backup), provided they contain a usable wallet and `channel.backup`.
> Restoring the archive alone does not import the SCB or request channel closes.

Copy backups and implementation-specific static channel backups to protected
remote storage. Keep the warning above in mind whenever restoring a Lightning
deployment.

> [!TIP]
> Keep a separate, off-site copy of LND's `channel.backup` and the wallet seed and any required passphrases.
> Update your separate SCB copy whenever it changes, including when channels open or close; a nightly archive cannot cover channels opened after it was taken.
> LND updates `channel.backup` atomically, so it can be copied while LND runs, without stopping the stack; see [LND's SCB documentation](https://github.com/lightningnetwork/lnd/blob/v0.21.3-beta/docs/recovery.md#obtaining-scbs).
> These scripts do not automate off-site, change-triggered SCB copies; arrange those separately.
> The SCB does not track every payment or replace the channel database and its revocation history.
> The [opt-lnd-autocompact fragment](../docker-compose-generator/docker-fragments/opt-lnd-autocompact.yml) enables LND's `db.bolt.auto-compact` to reduce bbolt database size, including for migration archives.

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
* Stop all containers in the BTCPay Docker Compose stack
* Archive the Docker volumes, generated secrets, and database dumps
  * Exclude blockchain data and caches that can be downloaded again
  * Exclude logs and Bitcoin LND's `data/graph` directory
  * Preserve Bitcoin LND's wallet and `channel.backup`, when present
  * Optionally [encrypt the archive](#set-a-backup-passphrase)
* Restart BTCPay Server
* Remove temporary files, such as the database dumps

If the backup directory does not exist yet, the script creates it.

The script validates each step and stops with an error if one fails.
When an unencrypted default backup completes successfully, it prints:

```
✅ Backup done => /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz
```

When encryption is enabled, the output filename is `backup.tar.gz.gpg` instead.
The backup and archive validation run while the stack is stopped, so backup size and compression affect downtime.
They do not currently stage a separate data copy and restart services before compression.
Use [migration mode](#planned-migration) only when you intend to leave the source stopped.

Store it safely, for instance, by copying it to a remote server.

After creating your first backup, test it by restoring it in a safe environment.
Keep a Lightning restore test isolated from peers and the Bitcoin network so it cannot act on an old channel state or conflict with your live node.

### Set a backup passphrase

To encrypt a backup, set the `BTCPAY_BACKUP_PASSPHRASE` environment variable.
The backup and restore scripts use this passphrase to encrypt and decrypt the backup file.
The encrypted backup is saved as `backup.tar.gz.gpg`, or `backup-migrate.tar.gz.gpg` with `--migrate`.
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
monitoring system that reports failures; do not silently discard backup errors.

Make sure the base path in the command (here `/root/BTCPayServer`) matches the output of `echo "$BTCPAY_BASE_DIRECTORY"`.

Each run replaces the same local `backup.tar.gz` or `backup.tar.gz.gpg` file.
The backup script does not provide retention or an off-host copy. Monitor the
cron result and use a separate, tested process to copy each successful archive
to protected off-host storage with the required retention.

### Planned migration

Use this workflow to move a healthy node and preserve its open channels, following [LND's offline migration requirements](https://docs.lightning.engineering/lightning-network-tools/lnd/migrating-lnd).
Prepare the destination with the matching BTCPay configuration and compatible LND version, following [the empty LND destination instructions](#prepare-an-empty-bitcoin-lnd-destination) and [destination secrets guidance](#prepare-destination-secrets).
Blockchain data is still excluded from the archive, so plan for the destination's blockchain synchronization separately.

Before starting, disable scheduled backups, automatic updates, and other jobs that can start the source stack, including service startup after a host reboot.
A scheduled default `btcpay-backup.sh` run would restart the source and could invalidate the migration snapshot.
`--migrate` does not install a persistent restart lock: do not run a default backup, `btcpay-up.sh`, or setup with `-i` on the source after taking the snapshot.

On the source, run as root from the BTCPay Docker directory:

```bash
./btcpay-backup.sh --migrate
```

This stops the entire BTCPay Docker Compose stack before making the database dumps.
Only the database containers are temporarily started for the dumps, then stopped again before archiving.
The archive includes Bitcoin LND's `data/graph` directory and the other LND data; the usual blockchain, cache, and log exclusions still apply.
The output is `backup-migrate.tar.gz`, or `backup-migrate.tar.gz.gpg` when encrypted.
Migration backups may take substantially longer than default backups.

On success, all containers in the BTCPay stack remain stopped after the backup.
If an error occurs after shutdown begins, the script attempts to stop the stack again.
If Docker cannot stop containers, the script fails and prints a manual-stop warning; confirm that the source is actually stopped before proceeding with migration.
The scripts do not stop unrelated Docker containers on the host.
Keep the source stopped and its scheduled restart jobs disabled.
If you resume operation on the source, make a new migration backup before migrating.

Copy the completed archive to the destination and restore it there:

```bash
./btcpay-restore.sh --migrate /var/backups/backup-migrate.tar.gz
```

For encryption, set `BTCPAY_BACKUP_PASSPHRASE` and use the `.gpg` filename instead.
Migration restore also leaves all destination BTCPay containers stopped, after temporarily running the databases to import their dumps.
Review the destination configuration and confirm that the source will remain permanently stopped, then start the destination:

```bash
./btcpay-up.sh
./bitcoin-lncli.sh getinfo
./bitcoin-lncli.sh listchannels
```

Do not import the SCB during a successful migration: the restored current database carries the open channels.
Never run the original and restored Lightning nodes simultaneously or restart the original after migration.

> [!WARNING]
> `--migrate` does not make an outdated archive safe.
> If the source processed further channel updates after the snapshot, do not start LND from that archive.
> Use the source's current data for a new migration, or follow LND's [disaster recovery guide](https://docs.lightning.engineering/lightning-network-tools/lnd/disaster-recovery) if that data was lost.
> The restore script cannot determine whether the source has advanced its channel state.

## Restore a Backup

Run `btcpay-restore.sh` with the absolute path to your archive.
The commands below restore a default backup; for a migration archive, follow [planned migration](#planned-migration) and pass `--migrate` explicitly.

Keep the original Lightning node stopped throughout recovery and afterward.
Both restore modes require a fresh Bitcoin LND destination and refuse to overlay nonempty existing LND data.
If the destination has existing data, preserve it separately and assess whether it is more current than the archive before [preparing an empty LND volume](#prepare-an-empty-bitcoin-lnd-destination).
This prevents a restored wallet from being mixed with an unrelated or stale channel database.

Default restore rejects archives containing Bitcoin LND graph data or marked as migration archives.
Migration restore requires an archive created with `btcpay-backup.sh --migrate`, including a channel database for every backed-up Bitcoin LND wallet network.
Older archives without the migration marker cannot be restored with `--migrate`; renaming an archive does not change its mode.
Use a new migration backup from a healthy source, or the [LND recovery guide](https://docs.lightning.engineering/lightning-network-tools/lnd/disaster-recovery) if only an old full database archive remains.

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

### Prepare an empty Bitcoin LND destination

On a new destination, configure the same deployment options as the source and use the setup script's `--install-only` option to avoid starting LND:

```bash
. ./btcpay-setup.sh --install-only
docker volume create generated_btcpay_datadir
```

The BTCPay volume is needed by the restore script to locate Docker's volume directory; the other volumes will be restored from the archive.

If setup has already started the destination, LND can have generated files even if you did not create a wallet manually.
Stop the destination stack and inspect its LND volume:

```bash
./btcpay-down.sh
docker ps --filter volume=generated_lnd_bitcoin_datadir --format '{{.Names}}'
lnd_data_dir=$(docker volume inspect generated_lnd_bitcoin_datadir --format '{{.Mountpoint}}')
printf 'Destination LND data: %s\n' "$lnd_data_dir"
```

Do not move data while the `docker ps` command lists any containers using that volume.
If the volume does not exist, there is no existing LND data to move aside.
Otherwise, inspect the printed directory first: it may hold a real wallet or more current channel state, which must be assessed before proceeding with this restore.

Once you have confirmed this is the destination data to replace, the following moves the entire directory into a private recovery directory and creates an empty volume directory.
It does not delete the existing wallet or channel data:

```bash
if [[ "$lnd_data_dir" == */generated_lnd_bitcoin_datadir/_data ]] &&
    [ -d "$lnd_data_dir" ] && [ ! -L "$lnd_data_dir" ]; then
  lnd_previous_dir=$(mktemp -d "$BTCPAY_BASE_DIRECTORY/lnd-before-restore.XXXXXX") &&
    mv -- "$lnd_data_dir" "$lnd_previous_dir/_data" &&
    mkdir -m 700 -- "$lnd_data_dir" &&
    printf 'Previous destination LND data preserved in %s\n' "$lnd_previous_dir"
else
  printf 'Unexpected LND data path; no data was moved.\n'
fi
```

Keep the saved directory until you have verified the recovery and accounted for any funds associated with that wallet.
Keep destination services stopped until the restore script starts them, or until the explicit startup step after migration restore.

### Prepare destination secrets

Current backups include the repository's `secrets/` directory, and restore refuses to overwrite an existing destination `secrets/` path.
Destination setup may have generated this directory even with `--install-only`.
If restore reports `The destination secrets path already exists`, stop the destination stack and inspect its secrets directory before moving it aside.
Once you have confirmed that the archived secrets should replace these destination secrets, preserve the existing directory as root:

```bash
destination_secrets_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker/secrets"
if [ -d "$destination_secrets_dir" ] && [ ! -L "$destination_secrets_dir" ]; then
  previous_secrets_dir=$(mktemp -d "$BTCPAY_BASE_DIRECTORY/secrets-before-restore.XXXXXX") &&
    mv -- "$destination_secrets_dir" "$previous_secrets_dir/secrets" &&
    printf 'Previous destination secrets preserved in %s\n' "$previous_secrets_dir"
else
  printf 'Expected a regular destination secrets directory; no secrets were moved.\n'
fi
```

Leave the destination `secrets/` path absent and retry the same restore command; the script recreates it from the archive before starting any containers.
Keep services stopped and do not rerun setup between moving the secrets and restoring them.
Do not merge old and restored secret directories.
Keep the saved directory until the restore has been verified.
For older archives without `secrets/`, leave the destination secrets in place; those archives do not restore them.

### Run the restore

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

The restore script performs these steps:

* Extract the backup archive (and decrypt it when necessary), then validate its mode and LND data
* Stop the entire BTCPay Docker Compose stack and check for existing destination LND data
* For default restore, preserve backed-up Bitcoin LND static channel backups in a separate host directory
* Restore generated secrets when the backup contains them, failing without overwriting when the destination already exists
* Restore the Docker volumes
* Start the database containers and wait until they are ready
* Import the database dumps with strict error handling
* Restart BTCPay Server for default restore, or stop the databases and leave the entire stack stopped for migration restore
* Remove the temporary restore directory after a successful restore

The restore script stops at any error it encounters, including a missing archive or incorrect decryption passphrase.
If an error occurs after shutdown begins and before a successful restart, the script attempts to leave the containers stopped to avoid running against partially restored data.
If Docker cannot stop them, the script prints a manual-stop warning; stop the containers and verify their state before continuing.
An error removing temporary files after a successful default restore does not stop the restored services again.
The temporary restore directory is retained for diagnosis and its path is printed in the error output.

When the default restore completes, you will see:

```
✅ Restore done
```

This message confirms that the restore steps and Compose startup completed; it
does not prove application health, public HTTPS, chain synchronization, or
Lightning state. Follow the [troubleshooting checks](./troubleshooting.md),
verify the expected services and public hostname, and inspect synchronization
before accepting payments.

> [!TIP]
> Always make sure your backup strategy is tested and fits your needs.
> No single solution fits every situation; this guide covers the common cases.
> For the latest guidance, feel free to ask on the BTCPay Server community channels.

Default restore restarts the containers and prints an LND recovery warning and commands when Bitcoin LND data is present.
It does not import `channel.backup` or request peer force closes automatically.
A successful script exit does not mean Lightning channel funds have been recovered: complete the recovery step below.

### Recovering LND with a static channel backup

These steps apply to Bitcoin LND using the default bbolt backend, including older default archives that excluded `channel.db`.
The commands below assume that a default restore completed successfully.
If the script rejected a full or outdated migration archive, it has not restored the wallet or created the persistent SCB copies described below.
Do not bypass that rejection by changing the archive marker or starting LND from its graph data.
Keep the full archive, extract any recovery files into a separate private staging directory outside Docker's live volumes, and follow [LND's disaster recovery procedure](https://docs.lightning.engineering/lightning-network-tools/lnd/disaster-recovery) using the original seed and an extracted SCB.
In archives made by `btcpay-backup.sh`, the SCB is under `volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/<network>/channel.backup`.
If the required seed or SCB is unavailable, preserve the wallet and channel database and seek specialist recovery assistance.

Before LND starts, the restore script copies each nonempty archived SCB into a new persistent directory on the host:

```text
$BTCPAY_BASE_DIRECTORY/lnd-recovery.XXXXXX/<network>/channel.backup
```

The script prints the actual directory and commands for each network found in the archive.
Keep this directory and the original archive until recovery is complete.
LND may overwrite its own managed `channel.backup` on startup, so use the preserved copy.
If there is no usable archived SCB, the script warns that only the wallet was restored; use a separately saved SCB for the same wallet or consult [LND's disaster recovery guide](https://docs.lightning.engineering/lightning-network-tools/lnd/disaster-recovery).

Run the printed commands as root from the destination's BTCPay Docker directory.
The following mainnet example uses a placeholder recovery directory; replace it with the exact path printed by your restore:

```bash
lnd_network=mainnet
lnd_recovery_dir="$BTCPAY_BASE_DIRECTORY/lnd-recovery.REPLACE_ME"
```

Wait for LND to be unlocked and synchronized, checking its status with:

```bash
./bitcoin-lncli.sh --network="$lnd_network" getinfo
```

Copy the preserved SCB into the container under a separate filename and verify it. Paths passed to `bitcoin-lncli.sh` are paths **inside the LND container**:

```bash
docker cp "$lnd_recovery_dir/$lnd_network/channel.backup" btcpayserver_lnd_bitcoin:/data/recovery-channel.backup
./bitcoin-lncli.sh --network="$lnd_network" verifychanbackup --multi_file=/data/recovery-channel.backup
```

Proceed only if verification succeeds.
The file to import is **`channel.backup`, not `channel.db`**.
The following command invokes `lncli restorechanbackup` through BTCPay's wrapper and **requests peers to force-close the backed-up channels**; it does not restore usable open channels:

```bash
./bitcoin-lncli.sh --network="$lnd_network" restorechanbackup --multi_file=/data/recovery-channel.backup
```

Monitor recovery with:

```bash
./bitcoin-lncli.sh --network="$lnd_network" pendingchannels
./bitcoin-lncli.sh --network="$lnd_network" walletbalance
```

Run these commands against LND configured for the SCB's Bitcoin network, and import only into the wallet that created it.
The CLI's `--network` option does not switch the running daemon to another network.
Use a newer separately saved SCB from that wallet if it includes channels opened after the archive was taken.

For channels covered by the SCB, subsequent settled payments do not invalidate the backup: recovery uses the peer's current state rather than reverting balances to the snapshot.
SCBs do not guarantee recovery of payments still in flight (HTLCs), or cover channels opened after the copy was saved.
See [LND's SCB documentation](https://github.com/lightningnetwork/lnd/blob/v0.21.3-beta/docs/recovery.md#off-chain-recovery).

Recovery depends on peers responding and incurs on-chain fees.
There is no fixed completion time or 14-day maximum: an unavailable peer can delay recovery indefinitely.
SCBs do not recreate missing revocation history or guarantee recovery against a dishonest peer.
