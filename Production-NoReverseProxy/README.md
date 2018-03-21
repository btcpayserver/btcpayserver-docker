# About this docker-compose

This `docker-compose` files can be used for production purpose.

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

This is the same architecture as [Production](../Production) but without NGINX as a reverse proxy.
It is suited for environment which already expose the host behind a reverse proxy handling HTTPS.

The relevant environment variables are:

* `NBITCOIN_NETWORK`: the blockchain identifier used by NBitcoin (eg., `regtest`, `testnet`, `mainnet`)
* `BTCPAY_HOST`: the external url used to access your server from internet. This domain name must point to this machine.
* `BTCPAY_PROTOCOL`: the protocol used to access this website from the internet (valid values: `http` and `https`, default: `https`)
* `LIGHTNING_ALIAS`: Optional, if using the integrated lightning feature, customize the alias of your nodes

The ports mapped on the host are:

1. `80` for the website
3. `9735` for the bitcoin lightning network node (if used)
4. `9736` for the litecoin lightning network node (if used)

Note that you need to set `BTCPAY_PROTOCOL=http` if you want to do some tests locally without https.

If you forget, you will get an error HTTP 400 when trying to register a new account on the website.