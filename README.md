#### Start accepting Bitcoin today with BTCPayServer! This guide will walk you through the installation.

# One-click deployment

For the easiest and fastest setup, host BTCPayServer on Microsoft Azure:

[![Deploy to Azure](https://azuredeploy.net/deploybutton.svg)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbtcpayserver%2Fbtcpayserver-azure%2Fmaster%2Fazuredeploy.json)

You can log into [Azure](https://azure.microsoft.com/en-us/account/) with your Microsoft account.

Final installation steps:

* Fill in the options: Resource Group
* Click 'Purchase' to confirm
* (Wait for deployment)
* View the deployment (in Notifications or Resource Groups)
* Verify you can connect to your instance with a browser: `https://SERVER-AZURE-DNS/`
* At your domain registrar, make sure you have [DNS](https://github.com/btcpayserver/btcpayserver-doc/blob/master/ChangeDomain.md#setting-up-your-dns-record) pointing your domain at your Azure deployment's IP.
* Browse to `https://SERVER-AZURE-DNS/`
* Register a new account (this account will be granted server administrator rights)
* Go to `https://SERVER-AZURE-DNS/server/maintenance`
* Enter your domain name and click on confirm
* (Wait 1 to 5 minutes)

That's it, you can now browse to `https://btcpay.YOUR-DOMAIN/` to create your store!

For advanced users, you can connect via SSH with information on `https://btcpay.YOUR-DOMAIN/server/services/ssh`, then you can:

* Run `docker ps` and `docker logs xxx` to view running processes
* Run `btcpay-down.sh` and `btcpay-up.sh` to stop and start the BTCPayServer

This video by Nicolas also demonstrates the above steps:

[![BTCPay - One Click Setup](http://img.youtube.com/vi/Bxs95BdEMHY/mqdefault.jpg)](https://www.youtube.com/watch?v=Bxs95BdEMHY "BTCPay - One Click Setup")

Approximate Cost (unpruned, Bitcoin-only): **60 USD per month**

After all your nodes have synced and you've confirmed everything works, follow [this guide](https://github.com/btcpayserver/btcpayserver-doc/blob/master/PennyPinching.md) to fine-tune for savings; costs should drop to **30 or 40 USD per month**.

# Architecture

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

As you can see, BTCPay depends on several pieces of infrastructure, mainly:

* A lightweight block explorer (NBXplorer),
* A database (PostgreSQL or SQLite),
* A full node (eg. Bitcoin Core)

There can be more dependencies if you support more than just standard Bitcoin transactions, including:

* [C-Lightning](https://github.com/ElementsProject/lightning)
* [LitecoinD](https://github.com/litecoin-project/litecoin) and other coin daemons
* And more...

Note: The setup process can be time consuming, but is heavily automated to make it a fun and easy experience.

# Full installation (for technical users)

You can also install BTCPayServer on your own machine or VPS instance.

The officially supported setup is driven by Docker (and Docker-Compose).

First, make sure you have a domain name pointing to your host (CNAME), with ports `443` and `80` externally accessible (and perhaps additional ports like `9735` and `9736` for Bitcoin and Litecoin lightning). Otherwise, you will have to set it manually by running `changedomain.sh`.

Let's assume it is `btcpay.EXAMPLE.com`.

If you want to support Litecoin, Bitcoin, and C-Lightning, and want HTTPS automatically configured by Nginx:

```bash
# Login as root
sudo su -

# Create a folder for BTCPay
mkdir BTCPayServer
cd BTCPayServer

# Clone this repository
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

# Run btcpay-setup.sh with the right parameters
export BTCPAY_HOST="btcpay.EXAMPLE.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="ltc"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
. ./btcpay-setup.sh -i

exit
```

`btcpay-setup.sh` will then:

* Install Docker
* Install Docker-Compose
* Make sure BTCPay starts at reboot via upstart or systemd
* Setup environment variables to use BTCPay utilities
* Add BTCPay utilities in /usr/bin
* Start BTCPay

You can read [the article](https://medium.com/@BtcpayServer/hosting-btcpay-server-for-cheap-2b27761fdb9d) for step by step instructions.

[![Docker automated build](https://img.shields.io/docker/automated/nicolasdorier/btcpayserver.svg)](https://hub.docker.com/r/nicolasdorier/btcpayserver/)


# Environment variables

`btcpay-setup.sh` will use the following environment variables:

* `BTCPAY_HOST`: The hostname of your website (eg. `btcpay.example.com`)
* `NBITCOIN_NETWORK`: The type of network to use (eg. `mainnet`, `testnet`, or `regtest`. Default: `mainnet`)
* `LIGHTNING_ALIAS`: An alias for your lightning network node, if used
* `BTCPAYGEN_CRYPTO1`: First supported crypto currency (eg. `btc`, `ltc`. Default: `btc`)
* `BTCPAYGEN_CRYPTO2`: Second supported crypto currency (eg. `btc`, `ltc`. Default: `(empty)`)
* `BTCPAYGEN_CRYPTON`: N'th supported crypto currency where N is 9 at maximum. (eg. `btc`, `ltc`. Default: `(empty)`)
* `BTCPAYGEN_REVERSEPROXY`: Specify reverse proxy to use; NGinx has HTTPS support. (eg. `nginx`, `traefik`,  `(empty)`. Default: `nginx`)
* `BTCPAYGEN_LIGHTNING`: Lightning network implementation to use (eg. `clightning`, `(empty)`)
* `BTCPAYGEN_SUBNAME`: The subname of the generated docker-compose file, where the full name is `Generated/docker-compose.SUBNAME.yml` (Default: `generated`)
* `BTCPAYGEN_ADDITIONAL_FRAGMENTS`: Semicolon-separated list of additional fragments you want to use (eg. `opt-save-storage`)
* `LETSENCRYPT_EMAIL`: An email will be sent to this address if certificate expires and fails to renew automatically (eg. `me@example.com`)
* `ACME_CA_URI`: The API endpoint to ask for HTTPS certificate (Default: `https://acme-v01.api.letsencrypt.org/directory`)
* `BTCPAY_HOST_SSHKEYFILE`: Optional, SSH private key that BTCPay can use to connect to this VM's SSH server. This key will be copied to BTCPay's data directory
* `BTCPAY_SSHTRUSTEDFINGERPRINTS`: Optional, BTCPay will ensure that it is connecting to the expected SSH server by checking the host's public key against these fingerprints
* `BTCPAYGEN_DOCKER_IMAGE`: Optional, Specify which generator image to use if you have customized the C# generator. Set to `btcpayserver/docker-compose-generator:local` to build the generator locally at runtime.
* `BTCPAY_IMAGE`: Optional, Specify which btcpayserver image to use if you have a customized btcpayserver.

# Tooling

A wide variety of useful scripts are available once BTCPay is installed:

* `bitcoin-cli.sh`: Access your Bitcoin node instance (for RPC)
* `bitcoin-lightning-cli.sh`: Access your C-Lightning node instance (for RPC)
* `changedomain.sh`: Change the domain of your BTCPayServer
* `btcpay-update.sh`: Update BTCPayServer to the latest version
* `btcpay-up.sh`: Run `docker-compose up`
* `btcpay-down.sh`: Run `docker-compose down`
* `btcpay-setup.sh`: Change the settings of your server
* `. ./btcpay-setup.sh`: Information about additional parameters
* `. ./btcpay-setup.sh -i`: Set up your BTCPayServer

# Under the hood

## Generated docker-compose <a id="generated-docker-compose"></a>

When you run `btcpay-setup.sh`, your environment variables are used by [build.sh](build.sh) (or [build.ps1](build.ps1)) to generate a docker-compose adapted for your needs. For the full list of options, see: [Environment variables](#environment-variables)

By default, the generated file is `Generated/docker-compose.generated.yml`, constructed from the relevant [Docker fragments](docker-compose-generator/docker-fragments) for your setup.

Available `BTCPAYGEN_ADDITIONAL_FRAGMENTS` currently are:

* [opt-save-storage](docker-compose-generator/docker-fragments/opt-save-storage.yml) will keep around 1 year of blocks (prune BTC for 100 GB)
* [opt-save-storage-s](docker-compose-generator/docker-fragments/opt-save-storage-s.yml) will keep around 6 months of blocks (prune BTC for 50 GB)
* [opt-save-storage-xs](docker-compose-generator/docker-fragments/opt-save-storage-xs.yml) will keep around 3 months of blocks (prune BTC for 25 GB)
* [opt-save-storage-xxs](docker-compose-generator/docker-fragments/opt-save-storage-xxs.yml) will keep around 2 weeks of blocks (prune BTC for 5 GB) (lightning not supported)
* [opt-lnd-autopilot](docker-compose-generator/docker-fragments/opt-lnd-autopilot.yml) will activate auto pilot on LND. (5 channels, 60% of allocation)
* [opt-save-memory](docker-compose-generator/docker-fragments/opt-save-memory.yml) will decrease the default dbcache at the expense of longer synchronization time (Useful if your machine is less than 2GB)
* [opt-add-btcqbo](docker-compose-generator/docker-fragments/opt-add-btcqbo.yml) will allow you to create an invoice on Quickbooks which include a way for your customer to pay on BTCPay Server (More information on this [github repository](https://github.com/JeffVandrewJr/btcqbo/), this plugin is maintained by [JeffVandrewJr](https://github.com/JeffVandrewJr), see more on [this video](https://www.youtube.com/watch?v=srgwL9ozg6c))

You can also create your own [custom fragments](#how-can-i-customize-the-generated-docker-compose-file).

For example, if you want `btc` and `ltc` support with `nginx` and `clightning` inside `Generated/docker-compose.custom.yml`:

Note: The first run might take a while, but following runs are instantaneous.

On Windows (run in [powershell](https://docs.microsoft.com/en-us/powershell/scripting/setup/starting-windows-powershell?view=powershell-6)):

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

Next, you will need to configure the runtime environment variables for `Generated/docker-compose.custom.yml`:

* If you are using NGinx, [read this](Production/README.md).
* If you are not using NGinx, [read this instead](Production-NoReverseProxy/README.md).

## Again, what does `btcpay-setup.sh` do?

`btcpay-setup.sh` is a utility which does the following:

1. Makes sure docker and docker-compose are installed on your system
2. Generates a docker-compose via `./build.sh`
3. Sets up an [Environment File](https://docs.docker.com/compose/env-file/) to configure your docker-compose
4. Sets up environment variables so the tools described in [Tooling](#tooling) can work
5. Adds symlinks of those tools into `/usr/bin`
6. Makes sure BTCPay restarts on reboot via upstart or systemd
7. Starts BTCPay via docker-compose

## Overview of files generated by `btcpay-setup.sh`

`/etc/profile.d/btcpay-env.sh` ensures that your environment variables are correctly setup when you login, so you can use the tools:

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
  export $(grep -v '^#' "$BTCPAY_ENV_FILE" | xargs)
fi
```

`/etc/systemd/system/btcpayserver.service` ensures that you can control btcpay via `systemctl`, and that BTCPayServer starts on reboot:

```ini
[Unit]
Description=BTCPayServer service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$(dirname $BTCPAY_ENV_FILE)" && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d -t "${COMPOSE_HTTP_TIMEOUT:-180}"'
ExecStop=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$(dirname $BTCPAY_ENV_FILE)" && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" stop -t "${COMPOSE_HTTP_TIMEOUT:-180}"'
ExecReload=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$(dirname $BTCPAY_ENV_FILE)" && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" restart -t "${COMPOSE_HTTP_TIMEOUT:-180}"'

[Install]
WantedBy=multi-user.target
```

`.env` (`$BTCPAY_ENV_FILE`) contains environment variables passed to the containers managed by your docker-compose:

```ini
BTCPAY_HOST=btcpay.EXAMPLE.com
ACME_CA_URI=https://acme-v01.api.letsencrypt.org/directory
NBITCOIN_NETWORK=mainnet
LETSENCRYPT_EMAIL=me@EXAMPLE.com
BTCPAY_SSHTRUSTEDFINGERPRINTS=SHA256:eSCD7NtQ/Q6IBl2iRB9caAQ3lDZd8s8iUL6SdeNnhpA
BTCPAY_SSHKEYFILE=/datadir/id_rsa
```

# How can I add an altcoin to BTCPayServer?

1. Add support for your crypto to [NBitcoin](https://github.com/MetacoSA/NBitcoin/tree/master/NBitcoin.Altcoins), [NBxplorer](https://github.com/dgarage/NBXplorer), and [BTCPayServer](https://github.com/btcpayserver/btcpayserver). (Use examples from other coins)
2. Create your own docker image ([Example for BTC](https://hub.docker.com/r/nicolasdorier/docker-bitcoin/))
3. Create a docker-compose fragment ([Example for BTC](docker-compose-generator/docker-fragments/bitcoin.yml))
4. Add your `CryptoDefinition` ([Example for BTC](docker-compose-generator/src/CryptoDefinition.cs))

`build.sh` is using a pre-built image of the `docker-compose generator` on [docker hub](https://hub.docker.com/r/btcpayserver/docker-compose-generator/).
If you modify the code source of `docker-compose generator` (for example, the `CryptoDefinition` [Example for BTC](docker-compose-generator/src/CryptoDefinition.cs)), you need to configure `build.sh` to use your own image by setting the environment variable `BTCPAYGEN_DOCKER_IMAGE` to `btcpayserver/docker-compose-generator:local`.

```bash
cd docker-compose-generator
BTCPAYGEN_DOCKER_IMAGE="btcpayserver/docker-compose-generator:local"
```

Or on powershell:
```powershell
cd docker-compose-generator
$BTCPAYGEN_DOCKER_IMAGE="btcpayserver/docker-compose-generator:local"
```

Then run `./build.sh` or `. .\build.ps1`.
This will generate your docker-compose in the `Generated` folder, which you can then run and test.

Note that BTCPayServer developers will not spend excessive time testing your image, so make sure it works.

# FAQ

## How can I modify my environment?

As root, run `. btcpay-setup.sh`; this will show you the environment variable it is expecting.
For example, if you support `btc` and `ltc` already, and want to add `btg`:

```bash
export BTCPAYGEN_CRYPTO3='btg'
. btcpay-setup.sh -i
```

## I deployed before `btcpay-setup.sh` existed (before May 17), can I migrate to this new system?

Yes, run the following commands to update:

```bash
sudo su -

cd $DOWNLOAD_ROOT/btcpayserver-docker
git checkout master
git pull
git checkout 9acb5d8067cb5c46f59858137feb699b41ac9f19
btcpay-update.sh
. ./btcpay-setup.sh -i
git checkout master
btcpay-update.sh

exit
```

## I'm getting an error on Windows: `Cannot create container for service docker: Mount denied`?

If you see this error:

`Cannot create container for service docker: b'Mount denied:\nThe source path "\\\\var\\\\run\\\\docker.sock:/var/run/docker.sock"\nis not a valid Windows path'`.

Run this in [powershell](https://docs.microsoft.com/en-us/powershell/scripting/setup/starting-windows-powershell?view=powershell-6):

```powershell
$Env:COMPOSE_CONVERT_WINDOWS_PATHS=1
```

Then, run `docker-compose -f EXAMPLE.yml up`.

This bug comes from Docker for Windows and is [tracked on Github](https://github.com/docker/for-win/issues/1829).

## How I can prune my node(s)?

This will prune your Bitcoin full node to a maximum of 100GB (of blocks):

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage"
. ./btcpay-setup.sh -i
```

Other options are [documented here](#generated-docker-compose).

## How can I customize the generated docker-compose file?

In some instances, you might want to customize your environment in more detail. While you could modify `Generated/docker-compose.generated.yml` manually, your changes would be overwritten the next time you run `btcpay-update.sh`.

Luckily, you can leverage `BTCPAYGEN_ADDITIONAL_FRAGMENTS` for this!

Let's enable **pruning to 60 GB**, for example:

First, copy [opt-save-storage](docker-compose-generator/docker-fragments/opt-save-storage.yml) into the [the docker fragment folder](docker-compose-generator/docker-fragments) as `opt-save-storage.custom.yml`. **Important:** the file must end with `.custom.yml`, or there will be git conflicts whenever you run `btcpay-update.sh`.

Modify the new `opt-save-storage.custom.yml` file to your taste:

```diff
@@ -14,8 +14,7 @@ version: "3"
 services:
   bitcoind:
     environment:
-       BITCOIN_EXTRA_ARGS: prune=100000
+       BITCOIN_EXTRA_ARGS: prune=60000
```

Then set it up:

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage.custom"
. ./btcpay-setup.sh -i
```
