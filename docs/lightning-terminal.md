# Lightning Terminal

[Lightning Terminal](https://github.com/lightninglabs/lightning-terminal) (LiT) is a software bundle for Lightning Labs products and services.
It integrates Loop, Pool, Faraday and Taproot Assets and includes LND Accounts and LNC Sessions.
This fragment requires Bitcoin LND. It selects that dependency automatically.

## Installation

This requires an existing BTCPay Server Docker deployment and must be run from a
root login shell. The fragment selects Bitcoin LND automatically.

> **Important:** Lightning Terminal receives LND's administrative macaroon and
> can control funds and channels. Generate LNC Sessions with caution.

The fragment enables LiT's automatic bbolt-to-SQL migration. Once that migration
completes, its data cannot be downgraded to a pre-0.17 LiT release or migrated
back to bbolt. Ensure the deployment and `lnd_lit_datadir` data are recoverable
before enabling or updating the fragment, and review the pinned LiT release's
migration notes.

Enable the fragment:

```bash
btcpay-fragments add opt-add-lightning-terminal
```

Lightning Terminal appears under **Server Settings > Services**.

## Command Line Interface

To interact with LiT you may use the command line interface over gRPC. To create an admin session:

`. ./litcli.sh sessions add --label "btcpay" --type admin`

To see the current Loop terms:

`. ./loop.sh terms`

To interact with Pool:

`. ./loop.sh getinfo`


To get a report from Faraday:

`. ./frcli.sh insights`

To interact with Taproot Assets:

`. ./tapcli.sh getinfo`

## Web Interface

To interact with LiT through the web-UI you will have to first generate a session through the command line (shown above).

Then, navigate to `https://terminal.lightning.engineering` and click on "Connect My Node."

Enter your pairing phrase and set a password. Each pairing phrase can only be used once.

You may inspect your sessions with:

`. ./bitcoin-litcli.sh sessions list all`

And revoke a session with:

`. ./bitcoin-litcli.sh sessions revoke --localpubkey`

## Troubleshooting

To see the logs of the Lightning Terminal service, you can run this command:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f lnd_lit
```
