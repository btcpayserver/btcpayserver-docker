# Updating

Run updates from a shell that can load the deployment profile:

```bash
sudo su -
btcpay-update.sh
```

The update process:

1. Pulls the latest commit of the checked-out branch.
2. Ensures the required Docker and Docker Compose versions are available.
3. Archives the currently retrievable Compose logs.
4. Regenerates Compose, routes, and missing secrets.
5. Reinstalls command wrappers and rewrites the container environment file.
6. Recreates the stack.
7. Removes unused images when `BTCPAY_UPDATE_CLEAN=true`.

Back up the deployment and review release notes before significant upgrades.
Do not keep manual changes in `Generated/docker-compose.generated.yml`; updates
regenerate it.

## Image Cleanup

`BTCPAY_UPDATE_CLEAN` defaults to `true`. Cleanup removes every unused Docker
image on the host except images marked with the generator label, including
unused images unrelated to BTCPay Server. Set it to `false` before updating if
the host relies on other cached images:

```bash
export BTCPAY_UPDATE_CLEAN="false"
. ./btcpay-setup.sh -i
```

## Archived Update Logs

Before replacing containers, updates save available Compose logs to:

```text
$BTCPAY_BASE_DIRECTORY/btcpay-update-logs/update-UTC_TIMESTAMP.log.gz
```

The directory is mode 700 and archives are created under a private umask. The
newest five successful archives are retained. A log-archive failure prints a
warning but does not stop the update.

Read an archive with:

```bash
gzip -cd "$BTCPAY_BASE_DIRECTORY/btcpay-update-logs/update-EXAMPLE.log.gz"
```

These files are snapshots of Docker logs still available immediately before
the update. They do not contain already rotated messages, later messages, host
SSH logs, or application files stored inside volumes. Retention is based on the
number of successful update archives, not age or disk usage.

## Diagnose a Failed Update

Start with the latest archived log and current service state:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs --timestamps
```

Then follow the [troubleshooting guide](./troubleshooting.md).
