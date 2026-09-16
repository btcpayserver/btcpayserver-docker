# Tallycoin Connect

Set up [Tallycoin Connect](https://github.com/djbooth007/tallycoin_connect) to
retrieve Lightning invoices through [Tallycoin](https://tallyco.in/). The
fragment requires Bitcoin LND and selects that dependency automatically.

## Installation

To install the Tallycoin Connect service, you need to set your Tallycoin API key and a password first.
The password is optional, but the service is public. Use a strong password.

You can either set `TALLYCOIN_PASSWD_CLEARTEXT` (plain text) or `TALLYCOIN_PASSWD`, which must be a sha256 hash of your login password.

```bash
export TALLYCOIN_APIKEY="my-tallycoin-api-key"
export TALLYCOIN_PASSWD_CLEARTEXT="sUpErSeCuRe"
btcpay-fragments add opt-add-tallycoin-connect
```

Tallycoin Connect appears under **Server Settings > Services** and is served at
`/tallycoin-connect/` on the BTCPay Server host.

## Troubleshooting

To see the logs of the Tallycoin Connect service, you can run this command:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f tallycoin_connect
```
