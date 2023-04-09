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
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-lightning-terminal"
. btcpay-setup.sh -i
```

Afterwards you should see Lightning Terminal appear as a service on the Server Settings > Services page in BTCPay Server.

## Troubleshooting

To see the logs of the Lightning Terminal service, you can run this command:

```bash
docker logs -f generated_lnd_lit_1
```

To enable the RPC Middleware Interceptor in the LND settings (lnd.conf), create a custom fragment in `docker-compose-generator/docker-fragments/opt-lnd-config.custom.yml` like this:

```yml
version: "3"
services:
  lnd_bitcoin:
    environment:
      LND_EXTRA_ARGS: |
        rpcmiddleware.enable=true
```

Afterwards the configuration has to be added to the additional fragments and setup needs to be run:

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-lnd-config.custom"
. ./btcpay-setup.sh -i
```
