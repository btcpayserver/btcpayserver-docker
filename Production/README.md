# About this docker-compose

The `docker-compose` can be used for production purpose.

It is composed of:

1. A full node (Bitcoin Core)
2. A lightweight block explorer ([NBxplorer](https://github.com/dgarage/NBXplorer))
3. A [BTCPay Server](https://github.com/btcpayserver/btcpayserver)
4. A database (Postgres)
5. A reverse proxy (NGINX)
6. Two containers configuring NGINX as a reverse proxy and renewing SSL certificates.

![Architecture](Production.png)

This `docker-compose` is used for [one click deploy on azure](https://github.com/btcpayserver/btcpayserver-azure) by an Ubuntu, it can be used on any docker supporting host.

The relevant environment variables are:

* `NBITCOIN_NETWORK`: the blockchain identifier used by NBitcoin (eg., `regtest`, `testnet`, `mainnet`)
* `BTCPAY_HOST`: the external url used to access the NGINX server from internet
* `LETSENCRYPT_EMAIL`: The email Let's Encrypt will use to notify you about certificate expiration.
* `BITCOIND_COOKIEFILE`: The relative path to RPC cookie file from bitcoin's data directory. (`.cookie` for mainnet, `regtest/.cookie` for regtest, `testnet3/.cookie` for testnet)
* `BITCOIND_NETWORKPARAMETER`: The blockchain identifier parameter used by bitcoind (`regtest=1` for regtest, `testnet=1` for testnet, `#mainnet=1` for mainnet)
* `ACME_CA_URI`: Let's encrypt API endpoint (`https://acme-staging.api.letsencrypt.org/directory` for a staging certificate, `https://acme-v01.api.letsencrypt.org/directory` for a production one)

Any unset or empty environment variable will be set for a `regtest` deployment.