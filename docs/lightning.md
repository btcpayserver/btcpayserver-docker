# Lightning

Lightning is optional and disabled by default. Choose one implementation with
`BTCPAYGEN_LIGHTNING` before running setup.

| Value | Implementation | Bitcoin | Groestlcoin |
|---|---|:-:|:-:|
| `clightning` | Core Lightning (CLN) | Yes | Yes |
| `lnd` | LND | Yes | Yes |
| `phoenixd` | Phoenixd | Yes | No |
| `none` | No Lightning service | N/A | N/A |

For a Bitcoin CLN deployment:

```bash
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
. ./btcpay-setup.sh -i
```

Use `lnd` or `phoenixd` instead to select another implementation.

## Network Access

Open a peer port only when the node should accept incoming connections. API
endpoints remain internal unless an optional route is enabled. See
[Lightning Ports](./networking.md#lightning-ports) and [Optional Nginx
Routes](./networking.md#optional-nginx-routes) for the canonical port and route
guidance.

## Command-line Access

The setup installs the applicable wrapper:

```bash
bitcoin-lightning-cli.sh getinfo  # CLN
bitcoin-lncli.sh getinfo          # LND
phoenix-cli.sh getinfo            # Phoenixd, from the repository directory
```

`phoenix-cli.sh` is not installed into `/usr/local/bin`; invoke it from the
repository unless you install your own wrapper.

## LND Options

LND-specific fragments include auto-compaction, autopilot, keysend, watchtower
server, and watchtower client. Browser applications such as Lightning Terminal,
ThunderHub, Sphinx Relay, and Helipad also require LND. See the [fragment
catalog](./fragments.md) for dependencies and exposed ports.

## Backups

For Lightning backup, disaster recovery, and migration requirements, follow
[Backup and Restore](./backup-restore.md#lightning-channel-backup).

For wallet, liquidity, and channel-management guidance, see the
[BTCPay Server Lightning documentation](https://docs.btcpayserver.org/LightningNetwork/).
