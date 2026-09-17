# Optional Fragments

Manage optional fragments with `btcpay-fragments`. `show` is read-only; all
commands that change fragments must run as root. Changes are applied immediately
and multiple fragment names can be passed at once:

```bash
btcpay-fragments add opt-add-mempool
btcpay-fragments remove opt-add-mempool
btcpay-fragments exclude opt-add-tor
btcpay-fragments unexclude opt-add-tor
btcpay-fragments show
```

`show` and successful changes return JSON containing the saved additional and
excluded fragments, the effective fragments from the last generated manifest,
and every fragment available in the current checkout. `effectiveFragments` is
empty before the first successful generation.
Adding a fragment removes it from the excluded set, and excluding one removes
it from the additional set. Repeating an operation that is already satisfied is
a no-op.

Dependencies and incompatibilities are resolved by the generator. Review each
linked fragment before enabling third-party services; not every image supports
every architecture or receives the same maintenance level.

## Resource Profiles

| Fragment | Purpose |
|---|---|
| [`opt-save-storage`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-save-storage.yml) | Prune supported nodes to about 100 GB |
| [`opt-save-storage-s`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-save-storage-s.yml) | Prune supported nodes to about 50 GB |
| [`opt-save-storage-xs`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-save-storage-xs.yml) | Prune supported nodes to about 25 GB |
| [`opt-save-storage-xxs`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-save-storage-xxs.yml) | Prune supported nodes to about 5 GB; not recommended for Lightning, but not rejected by the generator |
| [`opt-save-memory`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-save-memory.yml) | Reduce daemon cache and mempool settings on hosts with less than 1 GB of memory |
| [`opt-more-memory`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-more-memory.yml) | Increase daemon cache when more than 1 GB can be dedicated to Bitcoin Core |
| [`opt-txindex`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-txindex.yml) | Enable transaction indexing; incompatible with pruning |
| [`opt-mempoolfullrbf`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-mempoolfullrbf.yml) | Enable Bitcoin Core full-RBF policy; recommended automatically for Bitcoin |

Only one pruning profile can be selected. The two memory profiles are mutually
exclusive. Transaction indexing, ElectrumX, and the bundled Mempool service are
incompatible with pruning.

## Lightning and Node Features

| Fragment | Purpose and requirements |
|---|---|
| [`opt-lnd-autocompact`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-lnd-autocompact.yml) | Enable LND database auto-compaction |
| [`opt-lnd-autopilot`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-lnd-autopilot.yml) | Enable LND autopilot with its configured limits |
| [`opt-lnd-keysend`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-lnd-keysend.yml) | Enable LND keysend |
| [`opt-lnd-watchtower`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-lnd-watchtower.yml) | Enable the LND watchtower server and publish port 9911 |
| [`opt-lnd-wtclient`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-lnd-wtclient.yml) | Enable the LND watchtower client |
| [`opt-add-zmq`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-zmq.yml) | Enable internal ZMQ endpoints for supported nodes |
| [`opt-add-electrumx`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-electrumx.yml) | Add public ElectrumX; requires txindex and an unpruned node |
| [`opt-expose-unsafe`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-expose-unsafe.yml) | Publish Bitcoin P2P port 8333; trusted networks or restrictive firewall only |
| [`opt-monero-expose`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-monero-expose.yml) | Bind Monero daemon RPC to host loopback |
| [`opt-beldex-expose`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-beldex-expose.yml) | Bind Beldex daemon and wallet RPC to host loopback |
| [`opt-decred-expose`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-decred-expose.yml) | Bind Decred wallet RPC to host loopback |

The LND tuning fragments affect a selected LND service; some do not declare a
formal generator prerequisite, so confirm LND is enabled.

## Network Services

| Fragment | Purpose and requirements |
|---|---|
| [`opt-add-tor`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-tor.yml) | Add Tor hidden services and selected onion connectivity; recommended automatically |
| [`opt-add-cloudflared`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-cloudflared.yml) | Expose bundled Nginx through Cloudflare Tunnel and disable its local HTTPS companion; see the [guide](./cloudflare-tunnel.md) |
| [`opt-add-tor-relay`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-tor-relay.yml) | Run a public non-exit relay on port 9001; requires contact details and legal review |
| [`opt-add-pihole`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-pihole.yml) | Add Pi-hole DNS on TCP/UDP 53 for a trusted LAN; see the [guide](./pihole.md) |

## Applications and Integrations

| Fragment | Purpose and requirements |
|---|---|
| [`opt-add-btcqbo`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-btcqbo.yml) | Add the QuickBooks connector at `/btcqbo/` |
| [`opt-add-chatwoot`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-chatwoot.yml) | Add Chatwoot, Sidekiq, and Redis; requires a configuration file and dedicated host; see the [guide](./chatwoot.md) |
| [`opt-add-helipad`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-helipad.yml) | Add Podcasting 2.0 Helipad; requires Bitcoin LND |
| [`opt-add-lightning-terminal`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-lightning-terminal.yml) | Add Lightning Terminal; requires Bitcoin LND and `LIT_PASSWD`; see the [guide](./lightning-terminal.md) |
| [`opt-add-ltcmweb`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-ltcmweb.yml) | Add the Litecoin MWEB plugin daemon; requires Litecoin |
| [`opt-add-mempool`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-mempool.yml) | Add Mempool frontend/backend; requires ElectrumX, txindex, and an unpruned node |
| [`opt-add-nostr-relay`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-nostr-relay.yml) | Add a PostgreSQL-backed Nostr relay at `/nostr` |
| [`opt-add-shopify`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-shopify.yml) | Add the internal Shopify app deployer |
| [`opt-add-sphinxrelay`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-sphinxrelay.yml) | Add Sphinx Relay; requires Bitcoin LND and keysend |
| [`opt-add-taler-merchant`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-taler-merchant.yml) | Add the GNU Taler merchant backend |
| [`opt-add-teos`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-teos.yml) | Add a TEOS watchtower on port 9814; requires Bitcoin and ZMQ |
| [`opt-add-thunderhub`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-thunderhub.yml) | Add ThunderHub; requires Bitcoin LND |
| [`opt-add-woocommerce`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-woocommerce.yml) | Add WordPress and WooCommerce on a dedicated host |
| [`opt-add-zammad`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/docker-fragments/opt-add-zammad.yml) | Add the Zammad application stack; requires substantial additional resources |

## Custom Fragments

For settings or services not represented here, create a `.custom.yml` fragment
instead of editing generated Compose output. See [Customization](./customization.md).
