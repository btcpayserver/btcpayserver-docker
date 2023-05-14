# Lightning Terminal (LiT)

[Lightning Terminal](https://github.com/lightninglabs/lightning-terminal) (LiT) is a browser-based interface for managing channel liquidity.
It integrates the Lightning Labs services Loop, Poold and Faraday all in one and offers a web UI to manage them.
LND required.

## Installation

To install the Lightning Terminal service, you need to set a password for the login.

```bash
# Set password
export LIT_PASSWD="sUpErSeCuRe"

# Add fragment and run setup
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-lightning-terminal"
. btcpay-setup.sh -i
```

Afterwards you should see Lightning Terminal appear as a service on the Server Settings > Services page in BTCPay Server.

## Troubleshooting

To see the logs of the Lightning Terminal service, you can run this command:

```bash
docker logs -f generated_lnd_lit_1
```
