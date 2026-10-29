# Lightning Terminal

[Lightning Terminal](https://github.com/lightninglabs/lightning-terminal) (LiT) is a software bundle for Lightning Labs products and services.
It integrates Loop, Pool, Faraday and Taproot Assets and includes LND Accounts and LNC Sessions.
This fragment requires Bitcoin LND. It selects that dependency automatically.

## Installation

> **Important:** Lightning Terminal receives LND's administrative macaroon and
> can control funds and channels. Generate LNC Sessions with caution.

Enable the fragment:

```bash
btcpay-fragments add opt-add-lightning-terminal
```

The local web interface is disabled, and Lightning Terminal does not appear under
**Server Settings > Services**. Use the command-line tools or the hosted web
interface described below.

## Upgrading an Existing Installation

The fragment layout changed in [#1187](https://github.com/btcpayserver/btcpayserver-docker/pull/1187).
Previously, `lnd_lit_datadir` was mounted at `/root/.lit`; it is now mounted at
`/lit`, with LiT using `/lit/.lit`. Existing mainnet session data can therefore
remain at `/lit/mainnet` while LiT creates a new database at `/lit/.lit/mainnet`.
Previously paired LNC wallets, such as Zeus, may stop connecting without an
obvious error. Fresh installations do not need this migration.

See [SoulReaver-SS's migration steps on GitHub](https://github.com/btcpayserver/btcpayserver-docker/pull/1216#issuecomment-6476587112)
for affected mainnet installations. Back up the LiT volume before making changes,
and check that the paths match your installation. The old and newer session
databases are not merged.

## Command Line Interface

To interact with LiT you may use the command line interface over gRPC. Choose the
least privilege your client needs. For example, create a read-only session that
expires in one day:

```bash
litcli.sh sessions add --label "btcpay-readonly" --type readonly --expiry 86400
```

Session options:

- `--type readonly|admin|account|custom` selects the permissions. `readonly` is
  the default; `admin` grants full administrative access, including control of
  funds and channels. Only use `--type admin` for a trusted client that needs it.
- `--type account` restricts access to an existing LiT account, selected with
  `--account_id <account ID>`. See the [upstream accounts guide](https://github.com/lightninglabs/lightning-terminal/blob/v0.17.8/docs/accounts.md).
- `--type custom` accepts `--permission entity:action` (for example,
  `--permission info:read`) or `--uri` with an RPC method URI (for example,
  `--uri /lnrpc.Lightning/GetInfo`). Repeat these flags to include more permissions.
- `--expiry` is the session lifetime in **seconds**; the default is **90 days**
  (`7776000` seconds).

For example, allow only the `GetInfo` RPC for one hour:

```bash
litcli.sh sessions add --label "btcpay-info" --type custom --uri /lnrpc.Lightning/GetInfo --expiry 3600
```

Use `litcli.sh sessions add --help` for all available options. Create scoped
sessions through the CLI; the hosted Terminal interface does not provide these
session-scoping controls.

To see the current Loop terms:

`loop.sh terms`

To interact with Pool:

`pool.sh getinfo`


To get a report from Faraday:

`frcli.sh insights`

To interact with Taproot Assets:

`tapcli.sh getinfo`

## Hosted Web Interface

To interact with LiT through the hosted web interface, first generate a session through the command line (shown above).

Then, navigate to `https://terminal.lightning.engineering` and click on "Connect My Node."

Enter your pairing phrase and set a password. Each pairing phrase can only be used once.

You may inspect your sessions with:

`litcli.sh sessions list all`

Retrieve the local pubkey using the command above and revoke a session with:

`litcli.sh sessions revoke --localpubkey <your local pubkey>`

## Troubleshooting

To see the logs of the Lightning Terminal service, you can run this command:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f lnd_lit
```
