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

## Switch Implementations

Use `btcpay-switch ln` to select a configured Lightning implementation:

```bash
btcpay-switch ln clightning
btcpay-switch ln lnd
btcpay-switch ln phoenixd
btcpay-switch ln none
```

Switching away from an active implementation requires typing `YES`. For
noninteractive use, pass `--yes`. The command refuses to replace custom direct
Lightning fragment selections or LND-dependent applications; remove the listed
fragments first. It warns when an implementation is unsupported by some
selected chains and refuses a selection supported by none of them.

This changes configuration only. It does not migrate wallets, channels,
liquidity, or credentials, and it retains the previous implementation's Docker
volumes. Follow the implementation-specific migration guidance before
switching a funded node.

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

Old Lightning channel state is dangerous and can lead to loss of funds. A full
deployment backup does not by itself guarantee frozen channel state because the
backup script restarts the stack. Read [Backup and
Restore](./backup-restore.md#lightning-channel-backup) and follow the selected
implementation's migration guidance before moving or restoring a Lightning
deployment.

For wallet, liquidity, and channel-management guidance, see the
[BTCPay Server Lightning documentation](https://docs.btcpayserver.org/LightningNetwork/).
