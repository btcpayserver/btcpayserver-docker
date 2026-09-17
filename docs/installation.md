# Installation

The recommended production target is a dedicated Linux VPS. This guide explains
the requirements, setup effects, and completion steps.

**AI-assisted installation:** This repository includes a
[`vps-deployment` skill](https://github.com/btcpayserver/btcpayserver-docker/blob/master/.agents/skills/vps-deployment/SKILL.md) for
compatible AI agents. Ask the agent to use this skill to help select a VPS,
perform preflight checks, plan the deployment, guide installation, and verify
the result.

## Requirements

Use the [server specifications guide](./specs.md) to size a dedicated Linux host
for the chains and features you need.

Review [Networking](./networking.md#public-https) for domain, DNS, HTTPS, and
public-port requirements.

## Install a Bitcoin Deployment

Follow the current [installation commands in the root
README](https://github.com/btcpayserver/btcpayserver-docker#install), replacing
the example hostname before running them.

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

The recommended `btcpay-host` fragment allows BTCPay Server to invoke a
restricted set of host-management commands and changes host SSH configuration.
Excluding the fragment prevents BTCPay Server from receiving the host key, but
setup still prepares the host-side SSH integration and does not undo prior SSH
changes. Read [Configuration](./configuration.md) for details.

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
