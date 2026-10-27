# Customization

The generated Compose file is assembled from fragments. Do not edit
`Generated/docker-compose.generated.yml` directly; setup and updates overwrite
it.

## Create a Custom Fragment

Custom fragment filenames should end in `.custom.yml`. That suffix is ignored
by Git, avoiding conflicts during updates.

For example, copy the 100 GB pruning profile:

```bash
cp docker-compose-generator/docker-fragments/opt-save-storage.yml \
  docker-compose-generator/docker-fragments/opt-save-storage.custom.yml
```

Edit the custom file, then select its basename:

```bash
btcpay-fragments add opt-save-storage.custom
```

Fragment changes require root and immediately run setup to regenerate and apply
the stack. They are not selection-only edits.

The command preserves other selected fragments. Remove the custom fragment with:

```bash
btcpay-fragments remove opt-save-storage.custom
```

## Fragment Metadata

See [Declare Relationships](./development.md#declare-relationships) for the
canonical metadata reference. Use existing fragments as examples and validate
the resulting Compose file.

## Use an Existing Bitcoin Core Node

This advanced configuration connects BTCPay Server to Bitcoin Core already
running on the same Linux host instead of starting the bundled `bitcoind`
container. It does not configure Bitcoin Core or migrate an existing node.

This procedure only covers deployments without bundled Lightning. The bundled
Lightning implementations expect the bundled Bitcoin service. Do not use this
procedure to migrate a Lightning node with funds or channels.

Before continuing, configure Bitcoin Core so that:

- Its network matches `NBITCOIN_NETWORK` in BTCPay Server.
- Its RPC and P2P ports accept connections from the Docker network.
- A dedicated RPC username and strong password are available for NBXplorer.
- The RPC port is blocked from untrusted networks. Never expose Bitcoin Core RPC
  publicly.

Create
`docker-compose-generator/docker-fragments/bitcoin.custom.yml` with the
following content, replacing the ports and RPC credentials:

```yaml
services:
  btcpayserver:
    environment:
      BTCPAY_CHAINS: "btc"
      BTCPAY_BTCEXPLORERURL: http://nbxplorer:32838/
  nbxplorer:
    environment:
      NBXPLORER_CHAINS: "btc"
      NBXPLORER_BTCRPCURL: http://host.docker.internal:43782/
      NBXPLORER_BTCRPCUSER: "rpc-username"
      NBXPLORER_BTCRPCPASSWORD: "rpc-password"
      NBXPLORER_BTCNODEENDPOINT: host.docker.internal:39388
    extra_hosts:
      - "host.docker.internal:host-gateway"

required:
  - nbxplorer
```

The `required` declaration keeps NBXplorer in the generated stack after the
standard `bitcoin` fragment is excluded. `host-gateway` resolves the Linux host
without relying on a particular Docker bridge address.

### Initial Deployment

Follow the [installation guide](./installation.md) up to, but not including,
the first `. ./btcpay-setup.sh -i`. Select the custom fragment and exclude the
standard Bitcoin fragment before running setup:

```bash
export BTCPAYGEN_EXCLUDE_FRAGMENTS="${BTCPAYGEN_EXCLUDE_FRAGMENTS:+${BTCPAYGEN_EXCLUDE_FRAGMENTS};}bitcoin;bitcoincore"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="${BTCPAYGEN_ADDITIONAL_FRAGMENTS:+${BTCPAYGEN_ADDITIONAL_FRAGMENTS};}bitcoin.custom"
. ./btcpay-setup.sh -i
```

The environment variables are necessary during initial deployment because
`btcpay-fragments` requires the saved deployment profile created by setup.

### Existing Deployment

Plan for Bitcoin payment processing to be briefly unavailable while changing
fragments. Create the custom fragment first, verify that no bundled Lightning
implementation is selected, then run as root:

```bash
btcpay-fragments exclude bitcoin bitcoincore
btcpay-fragments add bitcoin.custom
```

Each command reapplies setup. The first removes both the default and explicitly
pinned Bitcoin Core fragments. The second adds the custom connection and
restores NBXplorer. Confirm the effective selection and services afterward:

```bash
btcpay-fragments show
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" config --services
```

The services must include `btcpayserver` and `nbxplorer`, and must not include
`bitcoind`. Check BTCPay Server's synchronization status before accepting
payments.

## Generate Without Installing

Set the complete generator selection and run `build.sh` from the repository
root:

```bash
BTCPAYGEN_CRYPTO1="btc" \
BTCPAYGEN_REVERSEPROXY="nginx" \
BTCPAYGEN_LIGHTNING="none" \
./build.sh
```

Unlike `btcpay-setup.sh`, direct `build.sh` use does not apply the setup
defaults, configure host SSH integration, or synchronize Nginx routes. The
setup and update scripts request those host changes explicitly with
`--setup-ssh` and `--sync-routes`. The output is
`Generated/docker-compose.generated.yml`; operate it explicitly with Docker
Compose and provide its runtime environment.

## Existing Reverse Proxy

For a standard installation behind an external reverse proxy, prefer the
documented setup path in [Networking](./networking.md#external-reverse-proxy)
instead of manually operating a custom generated stack.
