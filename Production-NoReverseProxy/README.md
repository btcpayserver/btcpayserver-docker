# How to use docker-compose without reverse proxy

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

This is the same architecture as [Production](../Production) but without NGINX as a reverse proxy.
It is suited for environment which already expose the host behind a reverse proxy handling HTTPS.

The relevant environment variables are:

* `NBITCOIN_NETWORK`: the blockchain identifier used by NBitcoin (eg., `regtest`, `testnet`, `mainnet`)
* `BTCPAY_HOST`: the external url used to access your server from internet. This domain name must point to this machine.
* `BTCPAY_ROOTPATH`: The root path directory where BTCPay is accessed, more information below. (default: /)
* `BTCPAY_PROTOCOL`: the protocol used to access this website from the internet (valid values: `http` and `https`, default: `https`)
* `LIGHTNING_ALIAS`: Optional, if using the integrated lightning feature, customize the alias of your nodes
* `BTCPAY_SSHKEYFILE`: Optional, SSH private key that BTCPay can use to connect to this VM's SSH server (You need to copy the key file on BTCPay's datadir volume)
* `BTCPAY_SSHTRUSTEDFINGERPRINTS`: Optional, BTCPay will ensure that it is connecting to the expected SSH server by checking the host public's key against those fingerprints

The ports mapped on the host are:

1. `80` for the website
3. `9735` for the bitcoin lightning network node (if used)
4. `9736` for the litecoin lightning network node (if used)

Note that you need to set `BTCPAY_PROTOCOL=http` if you want to do some tests locally without https.

If you forget, you will get an error HTTP 400 when trying to register a new account on the website.

## Example:

With Powershell:

```
$env:BTCPAY_ROOTPATH="/test";
$env:BTCPAY_PROTOCOL="http";
$env:BTCPAY_HOST="btcpay.example.com";
$env:BTCPAYGEN_REVERSEPROXY="none";
.\build.ps1
docker-compose -f "Generated/docker-compose.generated.yml" up --remove-orphans -d
```

With Linux:

```
export BTCPAY_ROOTPATH="/test"
export BTCPAY_PROTOCOL="http"
export BTCPAY_HOST="btcpay.example.com"
export BTCPAYGEN_REVERSEPROXY="none"
./build.sh
docker-compose -f "Generated/docker-compose.generated.yml" up --remove-orphans -d
```

Then edit your [host file](https://www.howtogeek.com/howto/27350/beginner-geek-how-to-edit-your-hosts-file/) with

```
127.0.0.1	sampleapi.example.com
```

Then browse `http://btcpay.example.com/test`.

Note: Chrome seems to block cookie to http://127.0.0.1:80/, which is why it is advised to use a custom domain like this.