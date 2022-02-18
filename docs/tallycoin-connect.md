# Tallycoin Connect

Set up [Tallycoin Connect](https://github.com/djbooth007/tallycoin_connect) on your BTCPay Server instance to allow for the retrieval of Lightning invoices via [Tallycoin](https://tallyco.in/).
LND required.

## Installation

To install the Tallycoin Connect service, you need to set your Tallycoin API key and a password first.
The password is optional, but as the service will be publicly available, you are strongly advised to require a secure password for the login.

You can either set `TALLYCOIN_PASSWD_CLEARTEXT` (plain text) or `TALLYCOIN_PASSWD`, which must be a sha256 hash of your login password.

```bash
# Set API key and password
export TALLYCOIN_APIKEY="my-tallycoin-api-key"
export TALLYCOIN_PASSWD_CLEARTEXT="sUpErSeCuRe"

# Add fragment and run setup
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-tallycoin-connect"
. btcpay-setup.sh -i
```

Afterwards you should see Tallycoin Connect appear as a service on the Server Settings > Services page in BTCPay Server.

## Troubleshooting

To see the logs of the Tallycoin Connect service, you can run this command:

```bash
docker logs -f generated_tallycoin_connect_1
```
