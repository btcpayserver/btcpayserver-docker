# BTCPay Server Docker Documentation

This documentation covers the official Docker deployment of BTCPay Server.
For product usage, stores, wallets, and integrations, see the
[BTCPay Server documentation](https://docs.btcpayserver.org/).

## Get Started

- [Installation](./installation.md): requirements, the production deployment path,
  and what the setup script changes on the host
- [Architecture](./architecture.md): required components, data flow, generated
  files, and optional services

## Configure the Stack

<a id="environment-variables"></a>
<a id="generated-docker-compose"></a>
<a id="how-i-can-prune-my-nodes"></a>

- [Configuration](./configuration.md): environment variables and storage or
  memory profiles
- [Networking](./networking.md): domains, ports, HTTPS, reverse proxies, tunnels,
  and optional Nginx routes
- [Lightning](./lightning.md): choosing and enabling CLN, LND, or Phoenixd
- [Cryptocurrencies](./cryptocurrencies.md): selecting supported chains and
  understanding support boundaries
- [Optional fragments](./fragments.md): the catalog of optional stack features

## Operate and Maintain

- [Operations](./operations.md): service lifecycle, command-line tools, logs, and
  database access
- [Updating](./updating.md): updating the repository and stack, archived update
  logs, and image cleanup
- [Backup and restore](./backup-restore.md): creating, encrypting, and restoring
  deployment backups
- [Troubleshooting](./troubleshooting.md): infrastructure checks and diagnostics
  to collect before requesting help

## Customize and Develop

<a id="how-can-i-customize-the-generated-docker-compose-file"></a>

- [Customization](./customization.md): generated Compose files and custom
  fragments
- [Development](./development.md): generator development and adding a new
  cryptocurrency

## Optional Services

- [Chatwoot](./chatwoot.md)
- [Cloudflare Tunnel](./cloudflare-tunnel.md)
- [Lightning Terminal](./lightning-terminal.md)
- [Pi-hole](./pihole.md)
- [Tallycoin Connect](./tallycoin-connect.md)

The [fragment catalog](./fragments.md) lists every available optional fragment,
including features that do not require a separate guide.

## Build Provenance

- [Supported images](./supported-images.md): image versions, architectures, and
  source Dockerfiles
- [Build all images from source](https://github.com/btcpayserver/btcpayserver-docker/tree/master/contrib/DockerFileBuildHelper)
- [FastSync](https://github.com/btcpayserver/btcpayserver-docker/tree/master/contrib/FastSync): accelerate initial Bitcoin node
  synchronization while understanding its trust model

## Help

Use the [BTCPay Server community chat](https://chat.btcpayserver.org/) for
deployment questions. Report reproducible defects in the Docker tooling on the
[btcpayserver-docker issue tracker](https://github.com/btcpayserver/btcpayserver-docker/issues).
