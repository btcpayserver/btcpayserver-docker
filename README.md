# BTCPay Server Docker

[![CI](https://github.com/btcpayserver/btcpayserver-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/btcpayserver/btcpayserver-docker/actions/workflows/ci.yml)

This repository contains the official Docker deployment for
[BTCPay Server](https://btcpayserver.org/). It generates and operates a Docker
Compose stack from a small set of environment variables and optional fragments.

If you are still choosing how to host BTCPay Server, start with the
[deployment overview](https://docs.btcpayserver.org/Deployment/). This repository
is for administrators who want to run and maintain the Docker deployment.

## What Gets Deployed

The standard Bitcoin deployment includes:

- BTCPay Server
- PostgreSQL
- NBXplorer
- Bitcoin Core
- Nginx with automatic HTTPS certificates
- Tor hidden services and selected Tor connectivity

Lightning implementations, additional cryptocurrencies, and other services are
optional. See the [architecture guide](docs/architecture.md) for how the
components fit together.

## Before Installing

Use the [server specifications guide](docs/specs.md) to select and size a VPS
for the chains and features you need.

Provider-specific cloud installation guides are available for:

- [LunaNode](https://docs.btcpayserver.org/Deployment/LunaNode/) (most popular)
- [Cloudzy](https://docs.btcpayserver.org/Deployment/Cloudzy/)
- [Clovyr](https://docs.btcpayserver.org/Deployment/Clovyr/)
- [Microsoft Azure](https://docs.btcpayserver.org/Deployment/Azure/)
- [Google Cloud](https://docs.btcpayserver.org/Deployment/GoogleCloud/)
- [Comet Cash](https://docs.btcpayserver.org/Deployment/CometCash/)

A domain is not required for local or manually proxied deployments. The bundled
automatic HTTPS setup requires a domain whose DNS records point to the server
and incoming TCP ports 80 and 443 open to the internet.

The setup script installs Docker and Docker Compose when needed. Read the
[installation guide](docs/installation.md) before adapting this process to an
existing server, another Linux distribution, or an external reverse proxy.

<a id="full-installation-for-technical-users"></a>

## Install

Replace `btcpay.example.com` with your domain, then run:

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
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-xs"

. ./btcpay-setup.sh -i
exit
```

The setup generates the Compose stack, installs the command-line utilities,
registers BTCPay Server to start at boot, and starts the services. Initial
Bitcoin synchronization can take time.

Open `https://btcpay.example.com` and register the first account, which becomes
the server administrator. Do this promptly, then follow the synchronization
status in the BTCPay Server interface before accepting payments.

## Next Steps

<!-- Legacy anchors retained for compatibility with old documentation links. -->
<a id="environment-variables"></a>
<a id="introduction"></a>
<a id="architecture"></a>
<a id="under-the-hood"></a>
<a id="faq"></a>
<a id="generated-docker-compose"></a>
<a id="how-i-can-prune-my-nodes"></a>
<a id="how-can-i-customize-the-generated-docker-compose-file"></a>
<a id="tooling"></a>
<a id="update-log-archives"></a>
<a id="again-what-does-btcpay-setupsh-do"></a>
<a id="overview-of-files-generated-by-btcpay-setupsh"></a>
<a id="how-can-i-add-an-altcoin-to-btcpayserver"></a>
<a id="how-can-i-modify-my-environment"></a>
<a id="how-can-i-manage-optional-nginx-routes"></a>
<a id="can-i-run-btcpay-server-on-ports-other-than-80-and-443"></a>
<a id="can-i-offload-https-termination"></a>
<a id="how-can-i-back-up-my-btcpay-server"></a>
<a id="how-can-i-connect-to-the-database"></a>
<a id="how-do-i-upgrade-my-btcpay-server-docker"></a>

- [Browse all Docker documentation](docs/README.md)
- [Configure the deployment](docs/configuration.md)
- [Choose a Lightning implementation](docs/lightning.md)
- [Configure domains, HTTPS, proxies, and routes](docs/networking.md)
- [Operate and monitor the server](docs/operations.md)
- [Update BTCPay Server](docs/updating.md)
- [Back up and restore the deployment](docs/backup-restore.md)
- [Enable optional fragments](docs/fragments.md)
- [Customize the generated Compose stack](docs/customization.md)
- [Review image versions, architectures, and source builds](docs/supported-images.md)

## Support

Check the [Docker troubleshooting guide](docs/troubleshooting.md) first. For
deployment help, use the [BTCPay Server community chat](https://chat.btcpayserver.org/).
Report reproducible problems with this repository on the
[GitHub issue tracker](https://github.com/btcpayserver/btcpayserver-docker/issues).

## Contributing

See the [development guide](docs/development.md) for generator internals,
testing, and adding cryptocurrency support. Changes are licensed under the
[MIT License](LICENSE).
