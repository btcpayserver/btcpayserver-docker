# Lightning Terminal

[Lightning Terminal](https://github.com/lightninglabs/lightning-terminal) (LiT) is a browser-based interface for managing channel liquidity.
It integrates the Lightning Labs services Loop, Poold and Faraday all in one and offers a web UI to manage them.
This fragment requires Bitcoin LND. It selects that dependency automatically.

## Installation

This requires an existing BTCPay Server Docker deployment and must be run from a
root login shell. The fragment selects Bitcoin LND automatically.

> **Important:** Lightning Terminal receives LND's administrative macaroon and
> can control funds and channels; it is not a read-only dashboard. Its UI and
> RPC endpoints are routed through the public BTCPay hostname. Use a unique,
> high-entropy UI password of at least eight characters and consider an
> additional access-control layer.

The fragment enables LiT's automatic bbolt-to-SQL migration. Once that migration
completes, its data cannot be downgraded to a pre-0.17 LiT release or migrated
back to bbolt. Ensure the deployment and `lnd_lit_datadir` data are recoverable
before enabling or updating the fragment, and review the pinned LiT release's
migration notes.

Set the UI password and enable the fragment:

```bash
export LIT_PASSWD="sUpErSeCuRe"
btcpay-fragments add opt-add-lightning-terminal
```

Setup persists `LIT_PASSWD` in the deployment `.env` file, and it is rendered
into the container command. Treat the file and Docker access as privileged and
rotate the password if it is disclosed.

Lightning Terminal appears under **Server Settings > Services** and is served at
`/lit/` on the BTCPay Server host.

## Troubleshooting

To see the logs of the Lightning Terminal service, you can run this command:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f lnd_lit
```
