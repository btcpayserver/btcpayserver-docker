# Lightning Terminal

[Lightning Terminal](https://github.com/lightninglabs/lightning-terminal) (LiT) is a browser-based interface for managing channel liquidity.
It integrates the Lightning Labs services Loop, Poold and Faraday all in one and offers a web UI to manage them.
This fragment requires Bitcoin LND. It selects that dependency automatically.

## Installation

Set a strong UI password and enable the fragment:

```bash
export LIT_PASSWD="sUpErSeCuRe"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-lightning-terminal"
. btcpay-setup.sh -i
```

Lightning Terminal appears under **Server Settings > Services** and is served at
`/lit/` on the BTCPay Server host.

## Troubleshooting

To see the logs of the Lightning Terminal service, you can run this command:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f lnd_lit
```
