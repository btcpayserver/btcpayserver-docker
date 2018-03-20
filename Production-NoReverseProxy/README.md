# About this docker-compose

This `docker-compose` files can be used for production purpose.

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

This is the same architecture as [Production](../Production) but without NGINX as a reverse proxy.
It is suited for environment which already expose the host behind a reverse proxy.

The relevant environment variables are:

* `NBITCOIN_NETWORK`: the blockchain identifier used by NBitcoin (eg., `regtest`, `testnet`, `mainnet`)
* `BTCPAY_HOST`: the external url used to access your server from internet. This domain name must point to this machine.

The port `80` is exposed.

** Note that in order to successfully use the BTCPay API, you must still access to it from an HTTPS url (https://<BTCPAY_HOST>/. **