# Operations

The setup installs applicable command wrappers into `/usr/local/bin`. A login
shell loads the saved deployment profile, including `BTCPAY_DOCKER_COMPOSE` and
`BTCPAY_BASE_DIRECTORY`.

## Service Lifecycle

```bash
btcpay-up.sh       # Create or start the stack
btcpay-down.sh     # Stop and remove stack containers
btcpay-restart.sh  # Restart, then ensure the stack is up
```

On Linux, setup also registers a oneshot systemd unit:

```bash
systemctl status btcpayserver
systemctl start btcpayserver
systemctl stop btcpayserver
systemctl reload btcpayserver
```

## Reconfigure and Update

- From `"$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"`,
  `. ./btcpay-setup.sh -i` regenerates the stack and immediately recreates
  affected services with the changed configuration.
- `btcpay-update.sh` pulls the repository, regenerates the stack, and recreates
  services. See [Updating](./updating.md).
- `changedomain.sh new.example.com` changes the primary domain. Disable
  domain-bound 2FA or security keys first to avoid locking yourself out.
- `btcpay-clean.sh` removes unused Docker images except generator-labeled
  images. It is not limited to BTCPay Server images.

## Node Commands

Switch between supported Bitcoin node selections with:

```bash
btcpay-switch node default
btcpay-switch node bitcoincore
```

`default` follows the implementation selected by the BTCPay Server team.
`bitcoincore` explicitly selects the Bitcoin Core fragment. The old
`switch-node.sh` utility has been replaced by `btcpay-switch node`.

To switch the Lightning implementation, see
[Switch Implementations](./lightning.md#switch-implementations).

## Service Commands

Wrappers are installed only when their service exists. Common examples:

```bash
bitcoin-cli.sh getblockchaininfo
bitcoin-lightning-cli.sh getinfo
bitcoin-lncli.sh getinfo
litecoin-cli.sh getblockchaininfo
elements-cli.sh getblockchaininfo
```

Other selected chains receive corresponding `*-cli.sh` or wallet wrappers.

## Compose Status and Logs

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs --timestamps
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f btcpayserver
```

Service names and container names come from the generated Compose file. Prefer
Compose commands over hardcoded container IDs.

## Optional Routes

Use `btcpay-routes show`, `add`, and `remove` to manage optional Nginx API
routes. See [Networking](./networking.md#optional-nginx-routes).

## PostgreSQL Access

Open a PostgreSQL session through the current Compose service:

```bash
docker exec -ti "$(docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps -q postgres)" \
  psql -U postgres
```

Inside `psql`:

```sql
\l
\c btcpayservermainnet
\dt
SELECT "Id", "Email" FROM "AspNetUsers";
\q
```

The database name includes the configured network. Main BTCPay Server tables
use the `public` schema; plugins can use schemas named after the plugin. Direct
database changes bypass application validation and should be avoided.

## Administrative Utility

`btcpay-admin.sh` provides selected account and server-policy operations, but it
currently targets the mainnet database name. Review the script before using it
on another network.
