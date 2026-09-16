# Firefly III

[Firefly III](https://www.firefly-iii.org/) is a self-hosted financial manager.

## How to use

Point a dedicated hostname at the server, then enable and initialize the
fragment:

```bash
export FIREFLY_HOST="firefly.example.com"
btcpay-fragments add opt-add-fireflyiii
. ./Tools/fireflyiii/init.sh
```

Access `https://firefly.example.com` and create the administrator account.

The bundled fragment currently contains a fixed application key and tracks the
`latest` Firefly III image. Review the fragment and Firefly III's deployment
requirements before using it with sensitive financial data.
