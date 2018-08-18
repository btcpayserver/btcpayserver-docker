# Introduction

This repository will help you to setup BTCPay and all its dependencies in a simple way:

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

As you can see, BTCPay depends on several piece of infrastructure, mainly:

* A lightweight block explorer (NBXplorer), 
* A database (Postgres, or SQLite),
* A full node (Bitcoin Core)

There is more dependencies, if you support more than just Bitcoin. (C-Lightning, LitecoinD etc...)
Setting up the dependencies correctly in a production environment might be time consuming. 

This repository is meant to setup your environment easily.

# How to use this?

## For complete noobs

If you have no knowledge of Linux administration or Docker, we advise you to host BTCPay on Microsoft Azure by opening an account then clicking here

[![Deploy to Azure](https://azuredeploy.net/deploybutton.svg)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbtcpayserver%2Fbtcpayserver-azure%2Fmaster%2Fazuredeploy.json)

Follow this video

[![BTCPay - One Click Setup](http://img.youtube.com/vi/Bxs95BdEMHY/mqdefault.jpg)](http://www.youtube.com/watch?v=Bxs95BdEMHY "BTCPay - One Click Setup")

This installation is convenient but will cost you around 60 USD per month.
After all your nodes are synched and you confirm things work fine, you can fine tune save additional money by following [this guide](https://github.com/btcpayserver/btcpayserver-doc/blob/master/PennyPinching.md), and drop to 30 or 40 USD per month.

## For technical user

If, for some reason, you don't want or can't use the Azure deployment explained above then you can install BTCPayServer on your own instance.

First step is to make sure you have a domain name pointing to your host, and that port `443` and `80` and externally accessible.
Let's assume it is `btcpay.example.com`.

If you want to support litecoin, bitcoin and clightning and having HTTPS automatically configured by nginx.

```bash
# Log as root
sudo su -

# Create a folder for BTCPay
mkdir BTCPayServer 
cd BTCPayServer

# Clone this repository
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

# Run btcpay-setup.sh with the right parameters
export BTCPAY_HOST="btcpay.example.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="ltc"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
. ./btcpay-setup.sh -i

```

`btcpay-setup.sh` will :

* Install Docker
* Install Docker-Compose
* Make sure BTCPay starts at reboot via upstart or systemd
* Setup environment variables to use BTCPay utilities
* Add BTCPay utilities in /usr/bin
* Start BTCPay

# Environment variables

`btcpay-setup.sh` will use the following environment variables:
* `BTCPAY_HOST`: The hostname of your website (eg. btcpay.example.com)
* `LETSENCRYPT_EMAIL`: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
* `NBITCOIN_NETWORK`: The type of network to use (eg. mainnet, testnet or regtest. Default`: mainnet)
* `LIGHTNING_ALIAS`: An alias for your lightning network node if used
* `BTCPAYGEN_CRYPTO1`: First supported crypto currency (eg. btc, ltc, none. Default`: btc)
* `BTCPAYGEN_CRYPTO2`: Second supported crypto currency (eg. btc, ltc, none. Default`: empty)
* `BTCPAYGEN_CRYPTON`: N th supported crypto currency where N is maximum at maximum 9. (eg. btc, ltc. Default: none)
* `BTCPAYGEN_REVERSEPROXY`: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, none. Default: nginx)
* `BTCPAYGEN_LIGHTNING`: Lightning network implementation to use (eg. clightning, none)
* `BTCPAYGEN_ADDITIONAL_FRAGMENTS`: Semi colon separated list of additional fragments you want to use (eg. `opt-save-storage`)
* `ACME_CA_URI`: The API endpoint to ask for HTTPS certificate (default: https://acme-v01.api.letsencrypt.org/directory)
* `BTCPAY_HOST_SSHKEYFILE`: Optional, SSH private key that BTCPay can use to connect to this VM's SSH server. This key will be copied on BTCPay's data directory

# Tooling <a name="tooling"></a>

A wide range of tooling get available on your system when btcpay is installed:

* `bitcoin-cli.sh` access your bitcoin node instance
* `bitcoin-lightning-cli.sh` access your clightning node instance
* `changedomain.sh` change the domain of your BTCPayServer
* `btcpay-update.sh` update BTCPay to the latest version
* `btcpay-up.sh` Run docker-compose up
* `btcpay-down.sh` Run docker-compose down
* `btcpay-setup.sh` change the settings of your server (run `. ./btcpay-setup.sh` to get more information about additional parameters, run `. ./btcpay-setup.sh -i` to setup again your btcpay server)

# Under the hood

## Generated docker-compose

Under the hood, your environment variable are used by [build.sh](build.sh) (or [build.ps1](build.ps1)) to generate a docker-compose adapted for your need.
By default, this script will generate `Generated/docker-compose.generated.yml`.

The build script is generating the docker-compose by gluing together the relevant [docker fragment](docker-compose-generator/docker-fragments) for your setup.

To configure your custom docker-compose, the following environment variables are supported:

* `BTCPAYGEN_CRYPTO1` to `BTCPAYGEN_CRYPTO9`: Specify support for a crypto currency. (Valid value: `btc`, `ltc`)
* `BTCPAYGEN_REVERSEPROXY`: Specify the reverse proxy to use (Valid value: `nginx`, `none`)
* `BTCPAYGEN_LIGHTNING`: Specify the lightning network implementation (Valid value: `clightning`, `none`)
* `BTCPAYGEN_SUBNAME`: The sub name of the generated docker-compose file, where the full name will be `Generated/docker-compose.SUBNAME.yml` (Default: `generated`)
* `BTCPAYGEN_ADDITIONAL_FRAGMENTS`: Semi colon separated list of additional fragments you want to use, eg. `opt-save-storage`. (Default: empty)

Available `BTCPAYGEN_ADDITIONAL_FRAGMENTS` currently are:

* [opt-save-storage](docker-compose-generator/docker-fragments/opt-save-storage.yml) will keep around 1 year of blocks (prune BTC for 100 GB)
* [opt-save-storage-s](docker-compose-generator/docker-fragments/opt-save-storage-s.yml) will keep around 6 months of blocks (prune BTC for 50 GB)
* [opt-save-storage-xxs](docker-compose-generator/docker-fragments/opt-save-storage-xxs.yml) will keep around 2 weeks of blocks (prune BTC for 5 GB)

You can also create your [own fragments](#custom-fragments).


For example, if you want `btc` and `ltc` support with `nginx` and `clightning` inside `Generated/docker-compose.custom.yml`:
Note: The first run might take a while, but next run are instantaneous.

On Windows:

```powershell
Invoke-Command {
    $BTCPAYGEN_CRYPTO1="btc"
    $BTCPAYGEN_CRYPTO2="ltc"
    $BTCPAYGEN_REVERSEPROXY="nginx"
    $BTCPAYGEN_LIGHTNING="clightning"
    $BTCPAYGEN_SUBNAME="custom"
    . .\build.ps1
}
```

On Linux:

```bash
BTCPAYGEN_CRYPTO1="btc" \
BTCPAYGEN_CRYPTO2="ltc" \
BTCPAYGEN_REVERSEPROXY="nginx" \
BTCPAYGEN_LIGHTNING="clightning" \
BTCPAYGEN_SUBNAME="custom" \
./build.sh
```

Next, you will need to configure the runtime environment variable for `Generated/docker-compose.custom.yml`. 

* If you are using [NGinx](Production/README.md)
* If you are [not using NGinx](Production-NoReverseProxy/README.md)

## What btcpay-setup do

`btcpay-setup.sh` utility is a tool which:

1. Make sure docker and docker-compose are installed on your system
2. Generate a docker-compose via `./build.sh`
3. Setup an [Environment File](https://docs.docker.com/compose/env-file/) to configure your docker-compose
4. Setup environment variables so the tools described in [tooling](#tooling) can work.
5. Add symbolic links of those tools in `/usr/bin`
6. Start docker-compose
7. Make sure it restart at reboot via upstart or systemd.


Here is an overview of the files generated by `btcpay-setup.sh`.

`/etc/profile.d/btcpay-env.sh` ensures that your environment variable are correctly setup when you log in, so you can use the tools.
```bash
export BTCPAYGEN_OLD_PREGEN="false"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2=""
export BTCPAYGEN_CRYPTO3=""
export BTCPAYGEN_CRYPTO4=""
export BTCPAYGEN_CRYPTO5=""
export BTCPAYGEN_CRYPTO6=""
export BTCPAYGEN_CRYPTO7=""
export BTCPAYGEN_CRYPTO8=""
export BTCPAYGEN_CRYPTO9=""
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS=""
export BTCPAY_DOCKER_COMPOSE="/var/lib/waagent/custom-script/download/0/btcpayserver-docker/Production/docker-compose.generated.yml"
export BTCPAY_BASE_DIRECTORY="/var/lib/waagent/custom-script/download/0"
export BTCPAY_ENV_FILE="/var/lib/waagent/custom-script/download/0/.env"
export BTCPAY_HOST_SSHKEYFILE="/root/.ssh/id_rsa_btcpay"
if cat $BTCPAY_ENV_FILE &> /dev/null; then
export BTCPAY_HOST="$(cat $BTCPAY_ENV_FILE | sed -n 's/^BTCPAY_HOST=\(.*\)$/\1/p')"
export LETSENCRYPT_EMAIL="$(cat $BTCPAY_ENV_FILE | sed -n 's/^LETSENCRYPT_EMAIL=\(.*\)$/\1/p')"
export NBITCOIN_NETWORK="$(cat $BTCPAY_ENV_FILE | sed -n 's/^NBITCOIN_NETWORK=\(.*\)$/\1/p')"
export LIGHTNING_ALIAS="$(cat $BTCPAY_ENV_FILE | sed -n 's/^LIGHTNING_ALIAS=\(.*\)$/\1/p')"
export ACME_CA_URI="$(cat $BTCPAY_ENV_FILE | sed -n 's/^ACME_CA_URI=\(.*\)$/\1/p')"
export BTCPAY_SSHKEYFILE="$(cat $BTCPAY_ENV_FILE | sed -n 's/^BTCPAY_SSHKEYFILE=\(.*\)$/\1/p')"
export BTCPAY_SSHTRUSTEDFINGERPRINTS="$(cat $BTCPAY_ENV_FILE | sed -n 's/^BTCPAY_SSHTRUSTEDFINGERPRINTS=\(.*\)$/\1/p')"
fi
```

`/etc/systemd/system/btcpayserver.service` file ensure that you can control btcpay via `systemctl`, and that btcpay server start on reboot:

```ini
[Unit]
Description=BTCPayServer service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$(dirname $BTCPAY_ENV_FILE)" && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d'
ExecStop=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$(dirname $BTCPAY_ENV_FILE)" && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" stop'
ExecReload=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$(dirname $BTCPAY_ENV_FILE)" && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" restart'

[Install]
WantedBy=multi-user.target
```

`.env` file (`$BTCPAY_ENV_FILE`) are the environment variable passed to the containers managed by your docker-compose:

```ini
BTCPAY_HOST=btcpay.example.com
ACME_CA_URI=https://acme-v01.api.letsencrypt.org/directory
NBITCOIN_NETWORK=mainnet
LETSENCRYPT_EMAIL=me@example.com
BTCPAY_SSHTRUSTEDFINGERPRINTS=SHA256:eSCD7NtQ/Q6IBl2iRB9caAQ3lDZd8s8iUL6SdeNnhpA
BTCPAY_SSHKEYFILE=/datadir/id_rsa
```

# How to extend with your own crypto?

1. Support for your crypto on [NBitcoin](https://github.com/MetacoSA/NBitcoin/tree/master/NBitcoin.Altcoins)/[NBxplorer](https://github.com/dgarage/NBXplorer)/[BTCPay Server](https://github.com/btcpayserver/btcpayserver). (Take example on other coins)
2. Create your own docker image ([Example for BTC](https://hub.docker.com/r/nicolasdorier/docker-bitcoin/))
3. Create a docker-compose fragment ([Example for BTC](docker-compose-generator/docker-fragments/bitcoin.yml))
4. Add your Crypto Definition ([Example for BTC](docker-compose-generator/src/CryptoDefinition.cs))

Now if you want to test, DOT NOT USE `build.sh`, because this utility is a pre-built docker image.
Instead, install [.NET Core 2.1 SDK](https://www.microsoft.com/net/download/windows) then run:

```bash
BTCPAYGEN_CRYPTO1="xxx"
BTCPAYGEN_SUBNAME="test"
cd docker-compose-generator/src
dotnet run
```

This will generate your docker-compose in the `Generated` folder, which you can then try by yourself.
Note that BTCPayServer developers will not spend time testing your image, so make sure it works.

# FAQ

## How can I modify my environment?

As root, run `. btcpay-setup.sh`, this will show you the environment variable it is expecting.
For example if you support `btc` and `ltc` already, and wants to add `btg`.

```bash
export BTCPAYGEN_CRYPTO3='btg'
. btcpay-setup.sh -i
```

## I deployed before btcpay-setup.sh existed, can I migrate to this new system? <a name="migration"></a>

Yes, the following command will migrate you to this new system:

```bash
sudo su -
btcpay-update.sh
cd $DOWNLOAD_ROOT/btcpayserver-docker
. ./btcpay-setup.sh -i
```

## Windows user error: Cannot create container for service docker: Mount denied

If you see this error:

`Cannot create container for service docker: b'Mount denied:\nThe source path "\\\\var\\\\run\\\\docker.sock:/var/run/docker.sock"\nis not a valid Windows path'`.

Run this command and run again `docker-compose -f <your.yml> up`.

```powershell
$Env:COMPOSE_CONVERT_WINDOWS_PATHS=1
```

This bug comes from Docker for Windows and is [tracked on github](https://github.com/docker/for-win/issues/1829).

## How I can prune my nodes?

This will prune your full node to keep maximum 100GB of blocks 

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage"
. ./btcpay-setup.sh -i
```

## The generated docker-compose is almost what I want... but not quite, how to customize? <a name="custom-fragments"></a>

In some instance, you might want to customize your environment in more details. Will you could modify `Generated/docker-compose.generated.yml` manually, your changes would be overwritten the next time you run `btcpay-update.sh`.

Luckily, you can leverage `BTCPAYGEN_ADDITIONAL_FRAGMENTS` like this:

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage"
. ./btcpay-setup.sh -i
```

[opt-save-storage](docker-compose-generator/docker-fragments/opt-save-storage.yml) will allow you to prune your node for targetting around 100 GB of space.

But what if you want to target 5 GB of space (For example, if you do not need lightning)?

First, Copy/Paste [opt-save-storage](docker-compose-generator/docker-fragments/opt-save-storage.yml) in the [the docker fragment folder](docker-compose-generator/docker-fragments) and name the file `opt-save-storage.custom.yml`. (Ending with `.custom.yml` is the important part, as it makes sure your fragment will not make a git conflict when you will run `btcpay-update.sh`)

Then modify the file to your taste
```diff
@@ -14,8 +14,7 @@ version: "3"
 services:
   bitcoind:
     environment:
-       BITCOIN_EXTRA_ARGS: prune=100000
+       BITCOIN_EXTRA_ARGS: prune=5000
```

Then set it up:

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage.custom"
. ./btcpay-setup.sh -i
```
