[![CircleCI](https://circleci.com/gh/btcpayserver/btcpayserver-docker.svg?style=svg)](https://app.circleci.com/pipelines/github/btcpayserver/btcpayserver-docker)

#### Start accepting Bitcoin today with BTCPay Server! This guide will walk you through the installation.

# Introduction

While [our instructions](https://docs.btcpayserver.org/LunaNodeWebDeployment/) cover how to install BTCPayServer in one click on Azure or Lunanode, BTCPay Server is not limited to those options.

You will find below information about how you can install BTCPay Server easily in any environment having docker available.

# Architecture

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/docs/img/Architecture.png)

As you can see, BTCPay depends on several pieces of infrastructure, mainly:

* A lightweight block explorer (NBXplorer),
* A database (PostgreSQL),
* A full node (eg. Bitcoin Core)

There can be more dependencies if you support more than just standard Bitcoin transactions, including:

* [Core Lightning (CLN)](https://github.com/ElementsProject/lightning)
* [LitecoinD](https://github.com/litecoin-project/litecoin) and other coin daemons
* And more...

Note: The setup process can be time consuming, but is heavily automated to make it a fun and easy experience.

Take a look at how BTCPay works in a video below.

[![](https://img.youtube.com/vi/nr0UNbz3AoQ/hqdefault.jpg)](https://www.youtube.com/watch?v=nr0UNbz3AoQ)

Here is a presentation of the global architecture at Advancing Bitcoin conference.

[![BTCPay - Architecture overview](https://i3.ytimg.com/vi/Up0dvorzSNM/maxresdefault.jpg)](https://www.youtube.com/watch?v=Up0dvorzSNM "BTCPay - Architecture overview")

# Full installation (for technical users)

You can also install BTCPay Server on your own machine or VPS instance.

The officially supported setup is driven by Docker (and Docker-Compose).

First, make sure you have a domain name pointing to your host `A record`, with ports `443` and `80` externally accessible. For Lightning Network, port `9735` is required (`9736` if you use Litecoin Lightning). Otherwise, you will have to set a domain manually by running `changedomain.sh`.

Let's assume your domain is `btcpay.EXAMPLE.com`.

The setup below assumes you want to support Bitcoin, Core Lightning (CLN), HTTPS automatically configured by Nginx. It also enables node pruning, which you can [modify](#generated-docker-compose) or ignore if you have enough disk space for a full node. Finally, your domain is `btcpay.EXAMPLE.com` should reflect your actual domain name.

[Environment variables](#environment-variables) can be tailored to your needs. Some variables require additional storage space.

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
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAY_ENABLE_SSH=true
. ./btcpay-setup.sh -i

exit
```

`btcpay-setup.sh` will then:

* Install Docker
* Install Docker-Compose
* Make sure BTCPay starts at reboot via upstart or systemd
* Setup environment variables to use BTCPay utilities
* Add BTCPay utilities in /usr/bin
* Start BTCPay Server

Video below guides you step by step on how to set up BTCPay Server on a VPS with Docker.

[![](https://img.youtube.com/vi/x6hqTFgHqhA/hqdefault.jpg)](https://www.youtube.com/watch?v=x6hqTFgHqhA)

Check out this video if you're interested in learning more about setting up [BTCPay with Docker Compose](https://www.youtube.com/playlist?list=PLH4m2oS2ratfaprAFx9E3ZDjwxNKvCk4e).

[![Docker automated build](https://img.shields.io/docker/automated/btcpayserver/btcpayserver.svg)](https://hub.docker.com/r/btcpayserver/btcpayserver/)

# Environment variables

`btcpay-setup.sh` will use the following environment variables:

* `BTCPAY_HOST`: The hostname of your website (eg. `btcpay.example.com`)
* `BTCPAY_ADDITIONAL_HOSTS`: Optional, specify additional domains to your BTCPayServer with https support if enabled. (eg. example2.com,example3.com)
* `REVERSEPROXY_HTTP_PORT`: The public port the reverse proxy binds to for HTTP traffic (default: 80)
* `REVERSEPROXY_HTTPS_PORT`: The public port the reverse proxy binds to for HTTPS traffic (default: 443)
* `REVERSEPROXY_DEFAULT_HOST`: Optional, if using a reverse proxy nginx, specify which website should be presented if the server is accessed by its IP or by an unrecognized domain name.
* `NOREVERSEPROXY_HTTP_PORT`: Optional, if not using a reverse proxy, specify which port should be opened for HTTP traffic. (default: 80)
* `NBITCOIN_NETWORK`: The type of network to use (eg. `mainnet`, `testnet`, or `regtest`. Default: `mainnet`)
* `LIGHTNING_ALIAS`: An alias for your lightning network node, if used
* `BTCPAYGEN_CRYPTO1`: First supported crypto currency (eg. `btc`, `ltc`. Default: `btc`)
* `BTCPAYGEN_CRYPTO2`: Second supported crypto currency (eg. `btc`, `ltc`. Default: `(empty)`)
* `BTCPAYGEN_CRYPTON`: N'th supported crypto currency where N is 9 at maximum. (eg. `btc`, `ltc`. Default: `(empty)`)
* `BTCPAYGEN_REVERSEPROXY`: Specify reverse proxy to use; NGinx has HTTPS support. (eg. `nginx`, `traefik`,  `(empty)`. Default: `nginx`)
* `BTCPAYGEN_LIGHTNING`: Lightning network implementation to use (eg. `clightning`, `lnd`, Default: `(empty)`)
* `BTCPAYGEN_SUBNAME`: The subname of the generated docker-compose file, where the full name is `Generated/docker-compose.SUBNAME.yml` (Default: `generated`)
* `BTCPAYGEN_ADDITIONAL_FRAGMENTS`: Semicolon-separated list of additional fragments you want to use (eg. `opt-save-storage`)
* `LETSENCRYPT_EMAIL`: An email will be sent to this address if certificate expires and fails to renew automatically (eg. `me@example.com`)
* `ACME_CA_URI`: The API endpoint to ask for HTTPS certificate (Default: `production`)
* `BTCPAY_ENABLE_SSH`: Optional, gives BTCPay Server SSH access to the host by allowing it to edit authorized_keys of the host, it can be used for managing the authorized_keys or updating BTCPay Server directly through the website. (Default: false)
* `BTCPAYGEN_DOCKER_IMAGE`: Optional, Specify which generator image to use if you have customized the C# generator. Set to `btcpayserver/docker-compose-generator:local` to build the generator locally at runtime.
* `BTCPAY_IMAGE`: Optional, Specify which btcpayserver image to use if you have a customized btcpayserver.
* `BTCPAYGEN_EXCLUDE_FRAGMENTS`:  Semicolon-separated list of fragments you want to forcefully exclude (eg. `litecoin-clightning`)
* `TOR_RELAY_NICKNAME`: If tor relay is activated with opt-add-tor-relay, the relay nickname
* `TOR_RELAY_EMAIL`: If tor relay is activated with opt-add-tor-relay, the email for Tor to contact you regarding your relay

Additionally, there are specific environment variables for some addons:

* `LIBREPATRON_HOST`: If libre patron is activated with [opt-add-librepatron](docker-compose-generator/docker-fragments/opt-add-librepatron.yml), the hostname of your libre patron website (eg. `librepatron.example.com`)
* `ZAMMAD_HOST`: If zammad is activated with [opt-add-zammad](docker-compose-generator/docker-fragments/opt-add-zammad.yml), the hostname of your zammad website (eg. `zammad.example.com`)
* `WOOCOMMERCE_HOST`: If woocommerce is activated with [opt-add-woocommerce](docker-compose-generator/docker-fragments/opt-add-woocommerce.yml), the hostname of your woocommerce website (eg. `store.example.com`)
* `EPS_XPUB`: If Electrum Personal Server (EPS) is activated with [opt-add-electrum-ps](docker-compose-generator/docker-fragments/opt-add-electrum-ps.yml), you must set the Extended Public Key (XPUB, YPUB or ZPUB) of the wallet you want to use, before first run of the EPS server.  If you accidentally start EPS without this, it will not work properly as the model of EPS is to monitor only specified wallets.
* If Bitcoin Wallet Tracker is activated with [opt-add-bwt](docker-compose-generator/docker-fragments/opt-add-bwt.yml),  you can use `BWT_XPUB`/`BWT_XPUB_*` (to set your XPUB/YPUB/ZPUB), `BWT_DESCRIPTOR`/`BWT_DESCRIPTOR_*` (for script descriptors), `BWT_RESCAN_SINCE` (set to the wallet creation date in YYYY-MM-DD to speed up the rescan), `BWT_BITCOIND_WALLET` and `BWT_GAP_LIMIT`.
* `LND_WTCLIENT_SWEEP_FEE`: If LND watchtower is activated with [opt-lnd-wtclient](docker-compose-generator/docker-fragments/opt-lnd-wtclient.yml), you can use `LND_WTCLIENT_SWEEP_FEE` to change the sweep fee used in constructing the justice transaction (default is 10 sat/byte)
* `FIREFLY_HOST`: If fireflyiii is activated with [opt-add-fireflyiii](docker-compose-generator/docker-fragments/opt-add-fireflyiii.yml), the hostname of your fireflyiii website (eg. `firefly.example.com`)
* `CLOUDFLARE_TUNNEL_TOKEN`: Used to expose your instance to clearnet with a Cloudflare Argo Tunnel (if cloudflare tunnel is activated with [opt-add-cloudflared](docker-compose-generator/docker-fragments/opt-add-cloudflared.yml), for setup instructions [see documentation](docs/cloudflare-tunnel.md))

# Tooling

A wide variety of useful scripts are available once BTCPay is installed:

* `bitcoin-cli.sh`: Access your Bitcoin node instance (for RPC)
* `bitcoin-lightning-cli.sh`: Access your CLN node instance (for RPC)
* `changedomain.sh`: Change the domain of your BTCPayServer (remember to disable 2FA/U2F first, as you risk being unable to log in to your account)
* `btcpay-update.sh`: Update BTCPayServer to the latest version
* `btcpay-up.sh`: Run `docker-compose up`
* `btcpay-down.sh`: Run `docker-compose down`
* `btcpay-setup.sh`: Change the settings of your server
* `btcpay-clean.sh`: Purge any unused docker images
* `. ./btcpay-setup.sh`: Information about additional parameters
* `. ./btcpay-setup.sh -i`: Set up your BTCPayServer
* `btcpay-restart.sh`: Restart your BTCPayServer

# Under the hood

## Generated docker-compose

When you run `btcpay-setup.sh`, your environment variables are used by [build.sh](build.sh) (or [build.ps1](build.ps1)) to generate a docker-compose adapted for your needs. For the full list of options, see: [Environment variables](#environment-variables)

By default, the generated file is `Generated/docker-compose.generated.yml`, constructed from the relevant [Docker fragments](docker-compose-generator/docker-fragments) for your setup.

Available `BTCPAYGEN_ADDITIONAL_FRAGMENTS` currently are:

* [opt-save-storage](docker-compose-generator/docker-fragments/opt-save-storage.yml) will keep around 1 year of blocks (prune BTC for 100 GB)
* [opt-save-storage-s](docker-compose-generator/docker-fragments/opt-save-storage-s.yml) will keep around 6 months of blocks (prune BTC for 50 GB)
* [opt-save-storage-xs](docker-compose-generator/docker-fragments/opt-save-storage-xs.yml) will keep around 3 months of blocks (prune BTC for 25 GB)
* [opt-save-storage-xxs](docker-compose-generator/docker-fragments/opt-save-storage-xxs.yml) will keep around 2 weeks of blocks (prune BTC for 5 GB) (lightning not supported)
* [opt-lnd-autocompact](docker-compose-generator/docker-fragments/opt-lnd-autocompact.yml) will activate auto compacting of LND database.
* [opt-lnd-autopilot](docker-compose-generator/docker-fragments/opt-lnd-autopilot.yml) will activate auto pilot on LND. (5 channels, 60% of allocation)
* [opt-lnd-keysend](docker-compose-generator/docker-fragments/opt-lnd-keysend.yml) will activate keysend on LND.
* [opt-lnd-wtclient](docker-compose-generator/docker-fragments/opt-lnd-wtclient.yml) will activate the watchtower client on LND. `LND_WTCLIENT_SWEEP_FEE` can be used to override the default 10 sat/byte justice transaction fee
* [opt-lnd-watchtower](docker-compose-generator/docker-fragments/opt-lnd-watchtower.yml) will activate the LND watchtower RPC
* [opt-save-memory](docker-compose-generator/docker-fragments/opt-save-memory.yml) will decrease the default dbcache at the expense of longer synchronization time. (Useful if your machine is less than 2GB)
* [opt-more-memory](docker-compose-generator/docker-fragments/opt-more-memory.yml) will increase the default dbcache to make synchronization faster (Useful if your machine is has around 4GB)
* [opt-add-btcqbo](docker-compose-generator/docker-fragments/opt-add-btcqbo.yml) will allow you to create an invoice on Quickbooks which include a way for your customer to pay on BTCPay Server (More information on this [github repository](https://github.com/JeffVandrewJr/btcqbo/), this add-on is maintained by [JeffVandrewJr](https://github.com/JeffVandrewJr), see more on [this video](https://www.youtube.com/watch?v=srgwL9ozg6c))
* [opt-add-librepatron](docker-compose-generator/docker-fragments/opt-add-librepatron.yml), for a self-hosted Patreon alternative backed by BTCPay (More information on this [github repository](https://github.com/JeffVandrewJr/patron), this add-on is maintained by [JeffVandrewJr](https://github.com/JeffVandrewJr).
* [opt-add-woocommerce](docker-compose-generator/docker-fragments/opt-add-woocommerce.yml), for a self-hosted woocommerce with BTCPay Server plugin pre installed.
* [opt-add-tor](docker-compose-generator/docker-fragments/opt-add-tor.yml), for exposing BTCPayServer, Woocommerce, your lightning nodes as hidden services and accept onion peers for your full node. Warning: This options is for working around NAT and firewall problems as well as to help protect your customer's privacy. This will not protect your privacy against a targeted attack against you.
* [opt-add-btctransmuter](docker-compose-generator/docker-fragments/opt-add-btctransmuter.yml), for a self-hosted IFTTT style service for crypto services such as fiat settlement. (More information on this [github repository](https://github.com/btcpayserver/btcTransmuter/)
* [opt-txindex](docker-compose-generator/docker-fragments/opt-txindex.yml), to enable txindex=1 in bitcoin.conf if you require txindexing for Bisq, DOJO, etc.
* [opt-expose-unsafe](docker-compose-generator/docker-fragments/opt-expose-unsafe.yml), to unsafely expose bitcoind P2P port 8333 if you require P2P for Bisq, DOJO, Esplora, etc. WARNING: ONLY USE ON TRUSTED LAN OR WITH FIREWALL RULES WHITELISTING SPECIFIC HOSTS
* [opt-add-tor-relay](docker-compose-generator/docker-fragments/opt-add-tor-relay.yml), for a non-exit tor relay. Make sure to have port 9001 accessible externally. [Please read the legal implications of running a tor relay](https://community.torproject.org/relay/community-resources/eff-tor-legal-faq) and [what resources are used to operate the relay](https://trac.torproject.org/projects/tor/wiki/TorRelayGuide#RelayRequirements).
* [opt-add-electrumx](docker-compose-generator/docker-fragments/opt-add-electrumx.yml), to integrate a full ElectrumX server (from official source) with BTCPay, using the BTCPay server's full bitcoin node for complete privacy when using your own Electrum wallet.  You can also open port 50002 up to the internet on your router etc, to be part of the ElectrumX network, helping other Electrum wallet users to get connected. The bitcoin option `-txindex` is mandatory for ElectrumX, and this fragment will enable it on your BTCPay server automatically - No need to use the fragment opt-txindex.yml.
* [opt-add-electrum-ps](docker-compose-generator/docker-fragments/opt-add-electrum-ps.yml), to integrate Electrum Personal Server (EPS) with BTCPay (EPS is a single-user alternative to the ElectrumX Server option above).  EPS will also use the BTCPay server's full bitcoin node for complete privacy when using your own Electrum wallet, for your own personal use (i.e. other users cannot use your server to verify transactions).  Also, the bitcoin option `-txindex` is NOT mandatory for EPS, and it will run on a pruned node (unlike ElectrumX).  You will need to add your XPUB/YPUB/ZPUB as environment variable `EPS_XPUB` before enabling EPS for the first time (see above section on environment variables, and see [full documentation](https://docs.btcpayserver.org/ElectrumPersonalServer/) for details).
* [opt-add-electrum-bwt](docker-compose-generator/docker-fragments/opt-add-bwt.yml), to integrate the [Bitcoin Wallet Tracker](https://github.com/bwt-dev/bwt) Electrum server, which uses a personal wallet index model similar to that of EPS. You will need to set `BWT_XPUB` with your XPUB/YPUB/ZPUB (see environment variables section). The server will only be available locally and through an onion service.
* [opt-add-configurator](docker-compose-generator/docker-fragments/opt-add-configurator.yml), to integrate the [BTCPay Server Configurator](https://install.btcpayserver.org) to manage your BTCPay deployment through a UI, and to allow new deployments elsewhere easily.
* [opt-add-pihole](docker-compose-generator/docker-fragments/opt-add-pihole.yml) ([See the documentation](docs/pihole.md))
* [opt-add-bluewallet-lndhub](docker-compose-generator/docker-fragments/opt-add-bluewallet-lndhub.yml) for [Bluewallet LNDHub](https://github.com/BlueWallet/LndHub) - Use non-custodial LND Lightning directly from your Bluewallet, and freely let others open accounts on your node. Fragment maintained by [maltokyo](https://github.com/maltokyo).
* [opt-add-ndlc](docker-compose-generator/docker-fragments/opt-add-ndlc.yml) ([See the documentation](docs/ndlc.md))
* [opt-add-lightning-terminal](docker-compose-generator/docker-fragments/opt-add-lightning-terminal.yml) for [Lightning Terminal/LiT](https://github.com/lightninglabs/lightning-terminal). Maintained by [dennisreimann](https://github.com/dennisreimann).
* [opt-add-mempool](docker-compose-generator/docker-fragments/opt-add-mempool.yml) for [Mempool](https://github.com/mempool/mempool). Maintained by [dennisreimann](https://github.com/dennisreimann).
* [opt-add-sphinxrelay](docker-compose-generator/docker-fragments/opt-add-sphinxrelay.yml) for [Sphinx Relay](https://github.com/stakwork/sphinx-relay). Maintained by [dennisreimann](https://github.com/dennisreimann).
* [opt-add-tallycoin-connect](docker-compose-generator/docker-fragments/opt-add-tallycoin-connect.yml) for [Tallycoin Connect](https://github.com/djbooth007/tallycoin_connect). Maintained by [dennisreimann](https://github.com/dennisreimann).
* [opt-add-thunderhub](docker-compose-generator/docker-fragments/opt-add-thunderhub.yml) for a LND Lightning Node Manager in your Browser. Maintained by [apotdevin](https://github.com/apotdevin).
* [opt-add-teos](docker-compose-generator/docker-fragments/opt-add-teos.yml) for [The Eye Of Satoshi](https://github.com/talaia-labs/python-teos), a BOLT13 Lightning Watchtower. Use port 9814 on your server or Tor to connect.
* [opt-add-chatwoot](docker-compose-generator/docker-fragments/opt-add-chatwoot.yml) for open source chat support system.  ([See the documentation](docs/chatwoot.md))
* [opt-add-zammad](docker-compose-generator/docker-fragments/opt-add-zammad.yml) for [Zammad](https://zammad.com/features), a web based open source helpdesk/customer support system with many features to manage customer communication via several channels like telephone, facebook, twitter, chat and e-mails
* [opt-monero-expose](docker-compose-generator/docker-fragments/opt-monero-expose.yml) to expose monero node's RPC port at 127.0.0.1:18081 to connect your own wallet. Use f.e. ssh port forwarding to forward to your own computer.
* [opt-add-fireflyiii](docker-compose-generator/docker-fragments/opt-add-fireflyiii.yml) ([See the documentation](docs/fireflyiii.md))
* [opt-add-joinmarket](docker-compose-generator/docker-fragments/opt-add-joinmarket.yml) ([See the documentation](docs/joinmarket.md))
* [opt-add-helipad](docker-compose-generator/docker-fragments/opt-add-helipad.yml) for [Podcastindex.org Helipad](https://github.com/Podcastindex-org/helipad). Requires LND.
* [opt-add-nostr-relay](docker-compose-generator/docker-fragments/opt-add-nostr-relay.yml) for [Nostr Relay](https://github.com/kukks/Nnostr).
* [opt-add-cloudflared](docker-compose-generator/docker-fragments/opt-add-cloudflared.yml) to expose your local server on clearnet painlessly ([see documentation](docs/cloudflare-tunnel.md)).
* [opt-add-torq](docker-compose-generator/docker-fragments/opt-add-torq.yml) to install [Torq](https://github.com/lncapital/torq) node management application. Requires LND.
* [opt-add-snapdrop](docker-compose-generator/docker-fragments/opt-add-snapdrop.yml) to install [Snapdrop](https://snapdrop.net/). You can then browse to `/snapdrop` of your server to access it.

You can also create your own [custom fragments](#how-can-i-customize-the-generated-docker-compose-file).

If you want to add an option to `BTCPAYGEN_ADDITIONAL_FRAGMENTS` and re-configure your install:

```bash
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-lnd-autopilot"
. btcpay-setup.sh -i
```

For example, if you want `btc` and `ltc` support with `nginx` and `clightning` inside `Generated/docker-compose.custom.yml`:

Note: The first run might take a while, but following runs are instantaneous.

On Windows (run in [powershell](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/starting-windows-powershell)):

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

ExecStart=/bin/bash -c  '. /etc/profile.d/btcpay-env.sh && cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker" && . helpers.sh && btcpay_up'
ExecStop=/bin/bash -c   '. /etc/profile.d/btcpay-env.sh && cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker" && . helpers.sh && btcpay_down'
ExecReload=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker" && . helpers.sh && btcpay_restart'

[Install]
WantedBy=multi-user.target
```

`.env` (`$BTCPAY_ENV_FILE`) contains environment variables passed to the containers managed by your docker-compose:

```ini
BTCPAY_HOST=btcpay.EXAMPLE.com
ACME_CA_URI=production
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

# Support

| Image | Version | x64 | arm32v7 | arm64v8 | links |
|---|---|:-:|:-:|:-:|:-:|
| btcpayserver/docker-compose-generator | latest | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver-docker/dcg-latest/docker-compose-generator/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver-docker/dcg-latest/docker-compose-generator/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver-docker/dcg-latest/docker-compose-generator/Dockerfile) | [Github](https://github.com/btcpayserver/btcpayserver-docker) - [DockerHub](https://hub.docker.com/r/btcpayserver/docker-compose-generator) |
| btcpayserver/lightning | v24.02.2 | [✔️](https://raw.githubusercontent.com/btcpayserver/lightning/basedon-v24.02.2/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/lightning/basedon-v24.02.2/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/lightning/basedon-v24.02.2/Dockerfile) | [Github](https://github.com/btcpayserver/lightning) - [DockerHub](https://hub.docker.com/r/btcpayserver/lightning) |
| shahanafarooqui/rtl | 0.15.0 | [✔️](https://raw.githubusercontent.com/Ride-The-Lightning/RTL/v0.15.0/dockerfiles/Dockerfile) | [✔️](https://raw.githubusercontent.com/Ride-The-Lightning/RTL/v0.15.0/dockerfiles/Dockerfile.arm32v7) | [✔️](https://raw.githubusercontent.com/Ride-The-Lightning/RTL/v0.15.0/dockerfiles/Dockerfile.arm64v8) | [Github](https://github.com/Ride-The-Lightning/RTL) - [DockerHub](https://hub.docker.com/r/shahanafarooqui/rtl) |
| btcpayserver/lnd | v0.17.4-beta | [✔️](https://raw.githubusercontent.com/btcpayserver/lnd/basedon-v0.17.4-beta/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/lnd/basedon-v0.17.4-beta/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/lnd/basedon-v0.17.4-beta/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/lnd) - [DockerHub](https://hub.docker.com/r/btcpayserver/lnd) |
| btcpayserver/bitcoin | 26.0 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Bitcoin/26.0/Bitcoin/26.0/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Bitcoin/26.0/Bitcoin/26.0/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Bitcoin/26.0/Bitcoin/26.0/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/bitcoin) |
| btcpayserver/btcpayserver | 1.13.2$<BTCPAY_BUILD_CONFIGURATION>? | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver/v1.13.2/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver/v1.13.2/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver/v1.13.2/Dockerfile) | [Github](https://github.com/btcpayserver/btcpayserver) - [DockerHub](https://hub.docker.com/r/btcpayserver/btcpayserver) |
| btcpayserver/monero | 0.18.3.1 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Monero/0.18.3.1/Monero/0.18.3.1/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Monero/0.18.3.1/Monero/0.18.3.1/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Monero/0.18.3.1/Monero/0.18.3.1/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/monero) |
| nicolasdorier/nbxplorer | 2.5.5 | [✔️](https://raw.githubusercontent.com/dgarage/nbxplorer/v2.5.5/Dockerfile) | [✔️](https://raw.githubusercontent.com/dgarage/nbxplorer/v2.5.5/Dockerfile) | [✔️](https://raw.githubusercontent.com/dgarage/nbxplorer/v2.5.5/Dockerfile) | [Github](https://github.com/dgarage/nbxplorer) - [DockerHub](https://hub.docker.com/r/nicolasdorier/nbxplorer) |
| btcpayserver/letsencrypt-nginx-proxy-companion | 2.2.9-2 | [✔️](https://raw.githubusercontent.com/btcpayserver/docker-letsencrypt-nginx-proxy-companion/v2.2.9-2/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/docker-letsencrypt-nginx-proxy-companion/v2.2.9-2/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/docker-letsencrypt-nginx-proxy-companion/v2.2.9-2/Dockerfile) | [Github](https://github.com/btcpayserver/docker-letsencrypt-nginx-proxy-companion) - [DockerHub](https://hub.docker.com/r/btcpayserver/letsencrypt-nginx-proxy-companion) |
| nginx | 1.25.3-bookworm | [✔️](https://raw.githubusercontent.com/nginxinc/docker-nginx/1.23.2/stable/debian/Dockerfile) | [✔️](https://raw.githubusercontent.com/nginxinc/docker-nginx/1.23.2/stable/debian/Dockerfile) | [✔️](https://raw.githubusercontent.com/nginxinc/docker-nginx/1.23.2/stable/debian/Dockerfile) | [Github](https://github.com/nginxinc/docker-nginx) - [DockerHub](https://hub.docker.com/_/nginx) |
| btcpayserver/docker-gen | 0.10.7 | [✔️](https://raw.githubusercontent.com/btcpayserver/docker-gen/0.10.7/Dockerfile.alpine) | [✔️](https://raw.githubusercontent.com/btcpayserver/docker-gen/0.10.7/Dockerfile.alpine) | [✔️](https://raw.githubusercontent.com/btcpayserver/docker-gen/0.10.7/Dockerfile.alpine) | [Github](https://github.com/btcpayserver/docker-gen) - [DockerHub](https://hub.docker.com/r/btcpayserver/docker-gen) |
| btcpayserver/btctransmuter | 0.0.59 | [✔️](https://raw.githubusercontent.com/btcpayserver/btctransmuter/v0.0.59/Dockerfiles/amd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btctransmuter/v0.0.59/Dockerfiles/arm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btctransmuter/v0.0.59/Dockerfiles/arm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/btctransmuter) - [DockerHub](https://hub.docker.com/r/btcpayserver/btctransmuter) |
| btcpayserver/cloudflared | 2023.10.0 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Cloudflared/2023.10.0/Cloudflared/2023.10.0/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Cloudflared/2023.10.0/Cloudflared/2023.10.0/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Cloudflared/2023.10.0/Cloudflared/2023.10.0/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/cloudflared) |
| btcpayserver/btcpayserver-configurator | 0.0.21 | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver-configurator/v0.0.21/Dockerfiles/amd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver-configurator/v0.0.21/Dockerfiles/arm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/btcpayserver-configurator/v0.0.21/Dockerfiles/arm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/btcpayserver-configurator) - [DockerHub](https://hub.docker.com/r/btcpayserver/btcpayserver-configurator) |
| btcpayserver/eps | 0.2.2 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/EPS/0.2.2/EPS/0.2.2/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/EPS/0.2.2/EPS/0.2.2/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/EPS/0.2.2/EPS/0.2.2/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/eps) |
| btcpayserver/joinmarket | 0.9.5 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/JoinMarket/0.9.5/JoinMarket/0.9.5/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/JoinMarket/0.9.5/JoinMarket/0.9.5/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/JoinMarket/0.9.5/JoinMarket/0.9.5/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/joinmarket) |
| nicolasdorier/ndlc-cli | 1.0.1 | [✔️](https://raw.githubusercontent.com/dgarage/ndlc/releases/1.0.1/amd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/dgarage/ndlc/releases/1.0.1/arm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/dgarage/ndlc/releases/1.0.1/arm64v8.Dockerfile) | [Github](https://github.com/dgarage/ndlc) - [DockerHub](https://hub.docker.com/r/nicolasdorier/ndlc-cli) |
| pihole/pihole | 2023.05.2 | [✔️](https://raw.githubusercontent.com/pi-hole/docker-pi-hole/2023.05.2/src/Dockerfile) | [✔️](https://raw.githubusercontent.com/pi-hole/docker-pi-hole/2023.05.2/src/Dockerfile) | [✔️](https://raw.githubusercontent.com/pi-hole/docker-pi-hole/2023.05.2/src/Dockerfile) | [Github](https://github.com/pi-hole/docker-pi-hole) - [DockerHub](https://hub.docker.com/r/pihole/pihole) |
| btcpayserver/snapdrop | 1.0 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Snapdrop/1.0/Snapdrop/1.0/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Snapdrop/1.0/Snapdrop/1.0/Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Snapdrop/1.0/Snapdrop/1.0/Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/snapdrop) |
| btcpayserver/tor | 0.4.8.10 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Tor/0.4.8.10/Tor/0.4.8.10/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Tor/0.4.8.10/Tor/0.4.8.10/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Tor/0.4.8.10/Tor/0.4.8.10/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/tor) |
| btcpayserver/woocommerce | 3.1.0 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/WooCommerce/3.1.0/WooCommerce/3.1.0/linuxamd64.Dockerfile) | ️❌ | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/WooCommerce/3.1.0/WooCommerce/3.1.0/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/woocommerce) |
| btcpayserver/postgres | 13.13 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Postgres/13.13/Postgres/13.13/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Postgres/13.13/Postgres/13.13/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Postgres/13.13/Postgres/13.13/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/postgres) |
| kamigawabul/btglnd | latest | [✔️](https://raw.githubusercontent.com/vutov/lnd/master/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/vutov/lnd) - [DockerHub](https://hub.docker.com/r/kamigawabul/btglnd) |
| kamigawabul/docker-bitcoingold | 0.15.2 | [✔️](https://raw.githubusercontent.com/Vutov/docker-bitcoin/master/bitcoingold/0.15.2/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/Vutov/docker-bitcoin) - [DockerHub](https://hub.docker.com/r/kamigawabul/docker-bitcoingold) |
| acinq/eclair | release-0.7.0 | [✔️](https://raw.githubusercontent.com/ACINQ/eclair/v0.7.0/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/ACINQ/eclair) - [DockerHub](https://hub.docker.com/r/acinq/eclair) |
| chekaz/docker-bitcoinplus | 2.7.0 | [✔️](https://raw.githubusercontent.com/ChekaZ/docker/master/bitcoinplus/2.7.0/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/ChekaZ/docker) - [DockerHub](https://hub.docker.com/r/chekaz/docker-bitcoinplus) |
| dalijolijo/docker-bitcore | 0.90.9.10 | [✔️](https://raw.githubusercontent.com/dalijolijo/btcpayserver-docker-bitcore/master/docker-bitcored/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/dalijolijo/btcpayserver-docker-bitcore) - [DockerHub](https://hub.docker.com/r/dalijolijo/docker-bitcore) |
| btcpayserver/dash | 20.1.0 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Dash/20.1.0/Dash/20.1.0/linuxamd64.Dockerfile) | ️❌ | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Dash/20.1.0/Dash/20.1.0/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/dash) |
| btcpayserver/dogecoin | 1.14.7 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Dogecoin/1.14.7/Dogecoin/1.14.7/linuxamd64.Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/dogecoin) |
| chekaz/docker-feathercoin | 0.16.3 | [✔️](https://raw.githubusercontent.com/ChekaZ/docker/master/feathercoin/0.16.3/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/ChekaZ/docker) - [DockerHub](https://hub.docker.com/r/chekaz/docker-feathercoin) |
| groestlcoin/lightning | v23.05 | [✔️](https://raw.githubusercontent.com/Groestlcoin/lightning/v23.05/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/Groestlcoin/lightning) - [DockerHub](https://hub.docker.com/r/groestlcoin/lightning) |
| groestlcoin/groestlcoin-lightning-charge | version-0.4.22 | [✔️](https://raw.githubusercontent.com/Groestlcoin/groestlcoin-lightning-charge/v0.4.22/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/Groestlcoin/groestlcoin-lightning-charge) - [DockerHub](https://hub.docker.com/r/groestlcoin/groestlcoin-lightning-charge) |
| groestlcoin/groestlcoin-spark | version-0.2.16 | [✔️](https://raw.githubusercontent.com/Groestlcoin/groestlcoin-spark/v0.2.16/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/Groestlcoin/groestlcoin-spark) - [DockerHub](https://hub.docker.com/r/groestlcoin/groestlcoin-spark) |
| groestlcoin/eclair | v0.6.0 | [✔️](https://raw.githubusercontent.com/Groestlcoin/eclair/v0.6.0/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/Groestlcoin/eclair) - [DockerHub](https://hub.docker.com/r/groestlcoin/eclair) |
| groestlcoin/lnd | v0.10.0-grs | [✔️](https://raw.githubusercontent.com/Groestlcoin/lnd/v0.10.0-grs/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/Groestlcoin/lnd) - [DockerHub](https://hub.docker.com/r/groestlcoin/lnd) |
| btcpayserver/groestlcoin | 25.0 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Groestlcoin/25.0/Groestlcoin/25.0/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Groestlcoin/25.0/Groestlcoin/25.0/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Groestlcoin/25.0/Groestlcoin/25.0/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/groestlcoin) |
| btcpayserver/elements | 23.2.1 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Elements/23.2.1/Elements/23.2.1/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Elements/23.2.1/Elements/23.2.1/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Elements/23.2.1/Elements/23.2.1/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/elements) |
| btcpayserver/litecoin | 0.21.2.1-2 | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Litecoin/0.21.2.1-2/Litecoin/0.21.2.1/linuxamd64.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Litecoin/0.21.2.1-2/Litecoin/0.21.2.1/linuxarm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/btcpayserver/dockerfile-deps/Litecoin/0.21.2.1-2/Litecoin/0.21.2.1/linuxarm64v8.Dockerfile) | [Github](https://github.com/btcpayserver/dockerfile-deps) - [DockerHub](https://hub.docker.com/r/btcpayserver/litecoin) |
| wakiyamap/docker-monacoin | 0.20.2 | [✔️](https://raw.githubusercontent.com/wakiyamap/docker-bitcoin/master/monacoin/0.20.2/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/wakiyamap/docker-bitcoin) - [DockerHub](https://hub.docker.com/r/wakiyamap/docker-monacoin) |
| redis | 6.2.2-buster | [✔️](https://raw.githubusercontent.com/docker-library/redis/f1a8498333ae3ab340b5b39fbac1d7e1dc0d628c/5.0/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/docker-library/redis) - [DockerHub](https://hub.docker.com/_/redis) |
| bluewalletorganization/lndhub | v1.4.1 | [✔️](https://raw.githubusercontent.com/BlueWallet/LndHub/v1.4.1/Dockerfile) | [✔️](https://raw.githubusercontent.com/BlueWallet/LndHub/v1.4.1/Dockerfile) | [✔️](https://raw.githubusercontent.com/BlueWallet/LndHub/v1.4.1/Dockerfile) | [Github](https://github.com/BlueWallet/LndHub) - [DockerHub](https://hub.docker.com/r/bluewalletorganization/lndhub) |
| jvandrew/btcqbo | 0.3.36 | [✔️](https://raw.githubusercontent.com/JeffVandrewJr/btcqbo/v0.3.36/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/JeffVandrewJr/btcqbo) - [DockerHub](https://hub.docker.com/r/jvandrew/btcqbo) |
| shesek/bwt | 0.2.2-electrum | [✔️](https://raw.githubusercontent.com/bwt-dev/bwt/v0.2.2/docker/Dockerfile) | [✔️](https://raw.githubusercontent.com/bwt-dev/bwt/v0.2.2/docker/arm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/bwt-dev/bwt/v0.2.2/docker/arm64v8.Dockerfile) | [Github](https://github.com/bwt-dev/bwt) - [DockerHub](https://hub.docker.com/r/shesek/bwt) |
| chatwoot/chatwoot | v1.7.0 | [✔️](https://raw.githubusercontent.com/chatwoot/chatwoot/v1.7.0/docker/Dockerfile) | [✔️](https://raw.githubusercontent.com/chatwoot/chatwoot/v1.7.0/docker/Dockerfile) | [✔️](https://raw.githubusercontent.com/chatwoot/chatwoot/v1.7.0/docker/Dockerfile) | [Github](https://github.com/chatwoot/chatwoot) - [DockerHub](https://hub.docker.com/r/chatwoot/chatwoot) |
| lukechilds/electrumx | latest | [✔️](https://raw.githubusercontent.com/lukechilds/docker-electrumx/master/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/lukechilds/docker-electrumx) - [DockerHub](https://hub.docker.com/r/lukechilds/electrumx) |
| fireflyiii/core | latest | [✔️](https://dev.azure.com/Firefly-III/66fb773b-063e-42d7-b6a5-e7729a22e8b3/_apis/git/repositories/e9c3dcf8-4533-4ef1-83cc-75527cab3377/items?path=%2FDockerfile&versionDescriptor%5BversionOptions%5D=0&versionDescriptor%5BversionType%5D=0&versionDescriptor%5Bversion%5D=main&resolveLfs=true&%24format=octetStream&api-version=5.0&download=true) | [✔️](https://dev.azure.com/Firefly-III/66fb773b-063e-42d7-b6a5-e7729a22e8b3/_apis/git/repositories/e9c3dcf8-4533-4ef1-83cc-75527cab3377/items?path=%2FDockerfile&versionDescriptor%5BversionOptions%5D=0&versionDescriptor%5BversionType%5D=0&versionDescriptor%5Bversion%5D=main&resolveLfs=true&%24format=octetStream&api-version=5.0&download=true) | [✔️](https://dev.azure.com/Firefly-III/66fb773b-063e-42d7-b6a5-e7729a22e8b3/_apis/git/repositories/e9c3dcf8-4533-4ef1-83cc-75527cab3377/items?path=%2FDockerfile&versionDescriptor%5BversionOptions%5D=0&versionDescriptor%5BversionType%5D=0&versionDescriptor%5Bversion%5D=main&resolveLfs=true&%24format=octetStream&api-version=5.0&download=true) | [Github](https://dev.azure.com/Firefly-III/_git/MainImage) - [DockerHub](https://hub.docker.com/r/fireflyiii/core) |
| podcastindexorg/podcasting20-helipad | v0.1.10 | [✔️](https://raw.githubusercontent.com/Podcastindex-org/helipad/v0.1.10/umbrel/Dockerfile) | [✔️](https://raw.githubusercontent.com/Podcastindex-org/helipad/v0.1.10/umbrel/Dockerfile) | [✔️](https://raw.githubusercontent.com/Podcastindex-org/helipad/v0.1.10/umbrel/Dockerfile) | [Github](https://github.com/Podcastindex-org/helipad) - [DockerHub](https://hub.docker.com/r/podcastindexorg/podcasting20-helipad) |
| jvandrew/librepatron | 0.7.39 | [✔️](https://raw.githubusercontent.com/JeffVandrewJr/patron/v0.7.39/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/JeffVandrewJr/patron) - [DockerHub](https://hub.docker.com/r/jvandrew/librepatron) |
| jvandrew/isso | atron.22 | [✔️](https://raw.githubusercontent.com/JeffVandrewJr/isso/patron.22/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/JeffVandrewJr/isso) - [DockerHub](https://hub.docker.com/r/jvandrew/isso) |
| lightninglabs/lightning-terminal | v0.12.3-alpha-path-prefix | [✔️](https://raw.githubusercontent.com/lightninglabs/lightning-terminal/v0.12.3-alpha/Dockerfile) | ️❌ | [✔️](https://raw.githubusercontent.com/lightninglabs/lightning-terminal/v0.12.3-alpha/Dockerfile) | [Github](https://github.com/lightninglabs/lightning-terminal) - [DockerHub](https://hub.docker.com/r/lightninglabs/lightning-terminal) |
| mempool/frontend | v2.5.0 | [✔️](https://raw.githubusercontent.com/mempool/mempool/v2.5.0/docker/frontend/Dockerfile) | [✔️](https://raw.githubusercontent.com/mempool/mempool/v2.5.0/docker/frontend/Dockerfile) | [✔️](https://raw.githubusercontent.com/mempool/mempool/v2.5.0/docker/frontend/Dockerfile) | [Github](https://github.com/mempool/mempool) - [DockerHub](https://hub.docker.com/r/mempool/frontend) |
| mempool/backend | v2.5.0 | [✔️](https://raw.githubusercontent.com/mempool/mempool/v2.5.0/docker/backend/Dockerfile) | [✔️](https://raw.githubusercontent.com/mempool/mempool/v2.5.0/docker/backend/Dockerfile) | [✔️](https://raw.githubusercontent.com/mempool/mempool/v2.5.0/docker/backend/Dockerfile) | [Github](https://github.com/mempool/mempool) - [DockerHub](https://hub.docker.com/r/mempool/backend) |
| mariadb | 10.11 | [✔️](https://raw.githubusercontent.com/docker-library/mariadb/master/10.11/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/docker-library/mariadb) - [DockerHub](https://hub.docker.com/_/mariadb) |
| kukks/nnostr-relay | v0.0.23 | [✔️](https://raw.githubusercontent.com/kukks/nnostr/Relay/v0.0.23/Relay/Dockerfile) | [✔️](https://raw.githubusercontent.com/kukks/nnostr/Relay/v0.0.23/Relay/Dockerfile) | [✔️](https://raw.githubusercontent.com/kukks/nnostr/Relay/v0.0.23/Relay/Dockerfile) | [Github](https://github.com/kukks/nnostr) - [DockerHub](https://hub.docker.com/r/kukks/nnostr-relay) |
| sphinxlightning/sphinx-relay | v2.2.9 | [✔️](https://raw.githubusercontent.com/stakwork/sphinx-relay/v2.2.9/Dockerfile) | [✔️](https://raw.githubusercontent.com/stakwork/sphinx-relay/v2.2.9/Dockerfile) | [✔️](https://raw.githubusercontent.com/stakwork/sphinx-relay/v2.2.9/Dockerfile) | [Github](https://github.com/stakwork/sphinx-relay) - [DockerHub](https://hub.docker.com/r/sphinxlightning/sphinx-relay) |
| djbooth007/tallycoin_connect | v1.8.0 | [✔️](https://raw.githubusercontent.com/djbooth007/tallycoin_connect/v1.8.0/Dockerfile) | [✔️](https://raw.githubusercontent.com/djbooth007/tallycoin_connect/v1.8.0/Dockerfile.arm32v7) | [✔️](https://raw.githubusercontent.com/djbooth007/tallycoin_connect/v1.8.0/Dockerfile.arm64v8) | [Github](https://github.com/djbooth007/tallycoin_connect) - [DockerHub](https://hub.docker.com/r/djbooth007/tallycoin_connect) |
| talaia/python-teos | latest | [✔️](https://raw.githubusercontent.com/talaia-labs/python-teos/master/docker/Dockerfile) | [✔️](https://raw.githubusercontent.com/talaia-labs/python-teos/master/docker/arm32v7.Dockerfile) | [✔️](https://raw.githubusercontent.com/talaia-labs/python-teos/master/docker/arm64v8.Dockerfile) | [Github](https://github.com/talaia-labs/python-teos) - [DockerHub](https://hub.docker.com/r/talaia/python-teos) |
| apotdevin/thunderhub | base-v0.13.29 | [✔️](https://raw.githubusercontent.com/apotdevin/thunderhub/v0.13.29/Dockerfile) | [✔️](https://raw.githubusercontent.com/apotdevin/thunderhub/v0.13.29/Dockerfile) | [✔️](https://raw.githubusercontent.com/apotdevin/thunderhub/v0.13.29/Dockerfile) | [Github](https://github.com/apotdevin/thunderhub) - [DockerHub](https://hub.docker.com/r/apotdevin/thunderhub) |
| lncapital/torq | 0.20.3 | [✔️](https://raw.githubusercontent.com/lncapital/torq/master/README.md) | [✔️](https://raw.githubusercontent.com/lncapital/torq/master/README.md) | [✔️](https://raw.githubusercontent.com/lncapital/torq/master/README.md) | [Github](https://github.com/lncapital/torq) - [DockerHub](https://hub.docker.com/r/lncapital/torq) |
| timescale/timescaledb | latest-pg14 | [✔️](https://raw.githubusercontent.com/timescale/timescaledb-docker/main/Dockerfile) | [✔️](https://raw.githubusercontent.com/timescale/timescaledb-docker/main/Dockerfile) | [✔️](https://raw.githubusercontent.com/timescale/timescaledb-docker/main/Dockerfile) | [Github](https://github.com/timescale/timescaledb-docker) - [DockerHub](https://hub.docker.com/r/timescale/timescaledb) |
| zammad/zammad-docker-compose | zammad-postgresql-3.4.0-4 | [✔️](https://raw.githubusercontent.com/zammad/zammad-docker-compose/ff20084ce2829486076e9781fe27407ca6cc09bb/containers/zammad-postgresql/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/zammad/zammad-docker-compose) - [DockerHub](https://hub.docker.com/r/zammad/zammad-docker-compose) |
| memcached | 1.5.22-alpine | [✔️](https://raw.githubusercontent.com/docker-library/memcached/eb38bf28263b8e5bb7367797cb7b181b65d769bd/alpine/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/docker-library/memcached) - [DockerHub](https://hub.docker.com/_/memcached) |
| traefik | v2.6 | [✔️](https://raw.githubusercontent.com/containous/traefik-library-image/master/scratch/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/containous/traefik-library-image) - [DockerHub](https://hub.docker.com/_/traefik) |
| chekaz/docker-trezarcoin | 0.13.0 | [✔️](https://raw.githubusercontent.com/ChekaZ/docker/master/trezarcoin/1.2.0/Dockerfile) | ️❌ | ️❌ | [Github](https://github.com/ChekaZ/docker) - [DockerHub](https://hub.docker.com/r/chekaz/docker-trezarcoin) |
| romanornr/docker-viacoin | 0.15.2 | [✔️](https://raw.githubusercontent.com/viacoin/docker-viacoin/master/viacoin/0.15.2/docker-viacoin) | ️❌ | ️❌ | [Github](https://github.com/viacoin/docker-viacoin) - [DockerHub](https://hub.docker.com/r/romanornr/docker-viacoin) |

# FAQ

## How can I modify my environment?

As root, run `. btcpay-setup.sh`; this will show you the environment variable it is expecting.
For example, if you support `btc` and `ltc` already, and want to add `btg`:

```bash
export BTCPAYGEN_CRYPTO3='btg'
. btcpay-setup.sh -i
```

## I deployed before `btcpay-setup.sh` existed (before May 17, 2018), can I migrate to this new system?

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

Run this in [powershell](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/starting-windows-powershell):

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
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-save-storage.custom"
. ./btcpay-setup.sh -i
```

## Can I run BTCPay Server on ports other than 80 and 443?

You can change the ports for HTTP and HTTPS by setting the environment variables `REVERSEPROXY_HTTP_PORT` and `REVERSEPROXY_HTTPS_PORT`. This is handy when ports 80 and 443 are already in use on your host, or you want to offload SSL termination with an existing web proxy.

When you set `REVERSEPROXY_HTTP_PORT` to another value than 80, the built-in Let's Encrypt certificate will not work, as Let's Encrypt will try to validate your SSL certificate request by connecting from the internet to your domain on port 80. This validation request should be able to reach BTCPay Server in order to receive the certificate.

If you need to run on a different port, it's best to terminate SSL using another web proxy and forward your traffic.

## Can I offload HTTPS termination?

Yes. Please [see the documentation](https://docs.btcpayserver.org/FAQ/FAQ-Deployment/#can-i-use-an-existing-nginx-server-as-a-reverse-proxy-with-ssl-termination).

## How can I back up my BTCPay Server?

See the [Backup & Restore](https://docs.btcpayserver.org/Docker/backup-restore/) guide in our documentation.

<details>
<summary>For backwards compatibility: Click here for the description of the old backup.sh process</summary>

:::warning
Please consider switching to the [new Backup & Restore process](https://docs.btcpayserver.org/Docker/backup-restore/), because the `backup.sh` will not be maintained anymore.
:::
We provide a backup script that dumps the database and saves the important files:

```bash
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
./backup.sh
```

This will save the backup locally as `/var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz`.
These are the options to customize the backup name and location:

* `BACKUP_TIMESTAMP=true` saves the backup with datetime as part of the file name, so that backups do not get overwritten.
* `BACKUP_PROVIDER=SCP` saves the backup remotely, requires additional `SCP_TARGET` environment variable (see below).
* `BACKUP_PROVIDER=Dropbox` saves the backup to Dropbox, requires additional `DROPBOX_TOKEN` environment variable (see below).

```bash
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"

# Backup with custom file name and timestamp:
BACKUP_TIMESTAMP=true ./backup.sh

# Backup via SCP:
BACKUP_PROVIDER=SCP SCP_TARGET=myhost:backups/btcpay ./backup.sh

# Backup to Dropbox:
BACKUP_PROVIDER=Dropbox DROPBOX_TOKEN=myDropboxToken ./backup.sh
```

You can also choose to only dump the database.
This option does not need to stop and restart the docker-containers:

```bash
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
./backup.sh --only-db
```
</details>

## How can I connect to the database?

On the server you can open a database session by connecting via `psql` as the postgres user:

```bash
docker exec -ti $(docker ps -a -q -f "name=postgres_1") psql -U postgres
```

Then, inside `psql` you can select a database and interact with the tables:

```bash
# list databases
\l

# connect to database
\c btcpayservermainnet

# list tables
\dt

# list users
SELECT "Id", "Email" FROM "AspNetUsers";

# end session
\q
```

The main BTCPay Server database tables are part of the `public` schema.
Plugins have their own schema, named after the plugin.

By default, only the tables of the `public` schema are shown.
If you want to also see and select the plugin tables, you need to extend the search path:

```bash
# list plugin schemas
SELECT * FROM pg_catalog.pg_namespace WHERE nspname LIKE 'BTCPayServer.%';

# extend search path
SET search_path TO "BTCPayServer.Plugins.MyPlugin", public;

# table list now also shows the MyPlugin tables
\dt
```

## How do I upgrade my BTCPay Server docker?

Run the script `./btcpay-update.sh` and patiently wait for your server to be upgraded.
