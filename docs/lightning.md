# Lightning

Lightning is optional and disabled by default. Choose one implementation with
`BTCPAYGEN_LIGHTNING` before running setup.

| Value | Implementation | Bitcoin | Groestlcoin |
|---|---|:-:|:-:|
| `clightning` | Core Lightning (CLN) | Yes | Yes |
| `lnd` | LND | Yes | Yes |
| `phoenixd` | Phoenixd | Yes | No |
| `none` | No Lightning service | Yes | Yes |

For a Bitcoin CLN deployment:

```bash
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="clightning"
. ./btcpay-setup.sh -i
```

Use `lnd` or `phoenixd` instead to select another implementation.

## Network Access

Bitcoin CLN and LND publish host TCP port 9735 for peer connections.
Bitcoin CLN additionally exposes container port 9736 for gRPC without publishing it on the host.
Open the peer port when you want the node to accept incoming connections. Other API
endpoints are internal unless you explicitly enable an optional Nginx route
with `btcpay-routes`; see [Networking](./networking.md).

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
ThunderHub, Sphinx Relay, Helipad, and Tallycoin Connect also require LND. See
the [fragment catalog](./fragments.md) for dependencies and exposed ports.

## Backups

Old Lightning channel state is dangerous and can lead to loss of funds. A full
deployment backup is suitable for a planned migration only when the old server
is shut down cleanly and is never restarted after the restored node starts.
Read [Backup and Restore](./backup-restore.md#lightning-channel-backup) before
moving or restoring a Lightning deployment.

For wallet, liquidity, and channel-management guidance, see the
[BTCPay Server Lightning documentation](https://docs.btcpayserver.org/LightningNetwork/).
