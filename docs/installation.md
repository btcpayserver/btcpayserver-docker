# Installation

The recommended production target is a dedicated Linux VPS. The root
[README](https://github.com/btcpayserver/btcpayserver-docker#install) contains the shortest complete installation path;
this guide explains its requirements and effects.

## Requirements

Use a server with:

- An `x86_64`, `armv7l`, or `aarch64` processor
- At least 2 GB of RAM and 80 GB of available storage for the documented pruned
  Bitcoin profile
- A domain with DNS records pointing to the server
- Incoming TCP ports 80 and 443 open to the internet
- Root access

Storage and memory needs increase when you add Lightning, more chains, an
unpruned node, transaction indexing, or optional services. The setup script does
not validate resource capacity.

Only Linux hosts are supported. The automated installation uses `apt-get` and
Docker's installation script, so a Debian or Ubuntu-style host is the expected
path.

## Install a Bitcoin Deployment

Replace the example host before running these commands:

```bash
sudo su -

mkdir BTCPayServer
cd BTCPayServer
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

export BTCPAY_HOST="btcpay.example.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_LIGHTNING="none"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s"

. ./btcpay-setup.sh -i
exit
```

The script must be sourced with `. ./btcpay-setup.sh`; executing it in a child
shell does not preserve the environment it configures.

## What Setup Changes

On Linux, the setup process:

1. Installs Docker when it is not available.
2. Installs the repository's pinned Docker Compose version.
3. Generates the selected Compose stack and missing secret files.
4. Stores container environment values in `$BTCPAY_BASE_DIRECTORY/.env`.
5. Stores the deployment profile in `/etc/profile.d/btcpay-env.sh`.
6. Installs applicable utility symlinks in `/usr/local/bin`.
7. Registers `/etc/systemd/system/btcpayserver.service`, or an Upstart service
   on older systems.
8. Pulls images and starts the stack.

If `/etc/docker/daemon.json` does not exist, setup creates a JSON-file logging
configuration limited to three 5 MB files. It does not replace an existing
Docker daemon configuration.

Host SSH integration is disabled by default. Enabling `BTCPAY_ENABLE_SSH=true`
allows BTCPay Server to invoke a restricted set of host-management commands and
changes host SSH configuration; read [Configuration](./configuration.md) before
enabling it.

## Complete the Installation

Open `https://btcpay.example.com` and create the first account. The first
registered account becomes the server administrator, so register it promptly.

The site can open before Bitcoin Core and NBXplorer finish synchronizing. Check
the synchronization status in BTCPay Server before accepting payments. You can
also inspect the node directly:

```bash
bitcoin-cli.sh getblockchaininfo
```

## Change the Deployment

Export the changed values and source setup again:

```bash
export BTCPAYGEN_LIGHTNING="clightning"
. ./btcpay-setup.sh -i
```

Setup persists the effective profile. Do not edit the generated Compose file
directly; use [configuration variables](./configuration.md) or
[custom fragments](./customization.md).
