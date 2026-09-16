# Configuration

`btcpay-setup.sh` uses environment variables to choose the generated stack and
configure its containers. Export changed values, then source setup again:

```bash
export NBITCOIN_NETWORK="testnet"
. ./btcpay-setup.sh -i
```

Running `. ./btcpay-setup.sh` without `-i` prints its current options and help.

## Stack Selection

| Variable | Purpose | Setup default |
|---|---|---|
| `BTCPAYGEN_CRYPTO1` ... `BTCPAYGEN_CRYPTO9` | Cryptocurrency codes to enable | `btc` in slot 1 |
| `BTCPAYGEN_LIGHTNING` | `clightning`, `lnd`, `phoenixd`, or `none` | `none` |
| `BTCPAYGEN_REVERSEPROXY` | `nginx` or `none` | `nginx` |
| `BTCPAYGEN_ADDITIONAL_FRAGMENTS` | Semicolon- or comma-separated optional fragments | Empty |
| `BTCPAYGEN_EXCLUDE_FRAGMENTS` | Recommended fragments to suppress | Empty |
| `BTCPAYGEN_DOCKER_IMAGE` | Compose generator image | `btcpayserver/docker-compose-generator` |
| `BTCPAYGEN_SUBNAME` | Generated Compose filename suffix | `generated` |

The setup utilities operate `Generated/docker-compose.generated.yml`; a custom
`BTCPAYGEN_SUBNAME` is intended for advanced, manually operated builds.

## Host and Network

| Variable | Purpose | Default |
|---|---|---|
| `BTCPAY_HOST` | Primary public hostname | Empty |
| `BTCPAY_ADDITIONAL_HOSTS` | Comma-separated additional hostnames | Empty |
| `BTCPAY_PROTOCOL` | External `https` or `http` protocol | `https` |
| `BTCPAY_LIGHTNING_HOST` | Host announced by Lightning instead of `BTCPAY_HOST` | Empty |
| `REVERSEPROXY_HTTP_PORT` | Nginx host HTTP port | `80` |
| `REVERSEPROXY_HTTPS_PORT` | Nginx host HTTPS port | `443` |
| `REVERSEPROXY_DEFAULT_HOST` | Destination for unknown hostnames | Empty |
| `NOREVERSEPROXY_HTTP_PORT` | BTCPay host port without Nginx | `80` |
| `TRUST_DOWNSTREAM_PROXY` | Trust forwarded headers from a protected external proxy | `false` |
| `LETSENCRYPT_EMAIL` | ACME expiry-notification address | Empty |
| `BTCPAY_LETSENCRYPT_HOSTS` | Hosts receiving certificates; explicit empty disables requests | All configured hosts |
| `ACME_CA_URI` | `production`, `staging`, or another ACME directory | `production` |

Only enable `TRUST_DOWNSTREAM_PROXY=true` when direct access to Nginx's HTTP
port is blocked and requests can arrive only through the trusted proxy.

See [Networking](./networking.md) before changing proxy or certificate settings.

## Runtime

| Variable | Purpose | Default |
|---|---|---|
| `NBITCOIN_NETWORK` | `mainnet`, `testnet`, or `regtest` | `mainnet` |
| `BTCPAY_IMAGE` | Override the BTCPay Server image | Release selected by fragments |
| `LIGHTNING_ALIAS` | Public Lightning node alias | Implementation default |
| `BTCPAY_ENABLE_SSH` | Permit restricted BTCPay-to-host management over SSH | `false` |
| `BTCPAY_UPDATE_CLEAN` | Remove unused images after updates | `true` |
| `COMPOSE_HTTP_TIMEOUT` | Compose operation timeout in seconds | `180` |

`BTCPAY_ROOTPATH` can serve BTCPay Server below a URL path, but setup does not
persist it in `/etc/profile.d/btcpay-env.sh` or the generated environment file.
Export it again before each setup, update, or `btcpay-up.sh` invocation that
could recreate the BTCPay Server container.

`BTCPAY_ENABLE_SSH=true` creates a host key, adds a restricted forced command to
root's `authorized_keys`, mounts the private key into BTCPay Server, and may
change `PermitRootLogin no` to `PermitRootLogin prohibit-password`.

## Storage and Memory Profiles

Choose at most one pruning profile:

| Fragment | Approximate retained block target |
|---|---:|
| `opt-save-storage` | 100 GB |
| `opt-save-storage-s` | 50 GB |
| `opt-save-storage-xs` | 25 GB |
| `opt-save-storage-xxs` | 5 GB; not recommended for Lightning |

Pruning is incompatible with `opt-txindex`, ElectrumX, and the bundled Mempool
service. `opt-save-memory` lowers daemon caches for constrained hosts;
`opt-more-memory` raises them. The two memory profiles are mutually exclusive.

## Add-on Variables

| Variable | Used by |
|---|---|
| `CLOUDFLARE_TUNNEL_TOKEN` | `opt-add-cloudflared` |
| `FIREFLY_HOST` | `opt-add-fireflyiii` |
| `CHATWOOT_HOST` | `opt-add-chatwoot` |
| `WOOCOMMERCE_HOST` | `opt-add-woocommerce` |
| `ZAMMAD_HOST` | `opt-add-zammad` |
| `PIHOLE_SERVERIP` | `opt-add-pihole` |
| `LIT_PASSWD` | `opt-add-lightning-terminal` |
| `TALLYCOIN_APIKEY` | `opt-add-tallycoin-connect` |
| `TALLYCOIN_PASSWD`, `TALLYCOIN_PASSWD_CLEARTEXT` | `opt-add-tallycoin-connect` |
| `LND_WTCLIENT_SWEEP_FEE` | `opt-lnd-wtclient` |
| `TOR_RELAY_NICKNAME`, `TOR_RELAY_EMAIL` | `opt-add-tor-relay` |
| `BTCPAY_DCR_WALLET_PASSPHRASE` | Decred wallet service |

Some third-party fragments require additional files or initialization. Follow
their linked guide in the [fragment catalog](./fragments.md).

## Operational Variables

- `BTCPAY_BACKUP_PASSPHRASE` encrypts and decrypts deployment backups.
- `BTCPAY_DATABASE_READY_TIMEOUT` controls how long backup and restore wait for
  databases; the default is 60 seconds.
- `BTCPAY_DOCKER_PULL_FLAGS` adds flags to generated image pull commands.
- `BTCPAY_BASE_DIRECTORY`, `BTCPAY_DOCKER_COMPOSE`, and `BTCPAY_ENV_FILE` are
  managed paths. Avoid overriding them in a normal installation.
