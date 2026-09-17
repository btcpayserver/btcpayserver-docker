# Cryptocurrencies

The generator can select up to nine cryptocurrency definitions through
`BTCPAYGEN_CRYPTO1` to `BTCPAYGEN_CRYPTO9`. Duplicate values are ignored.

Bitcoin and Litecoin are maintained by the BTCPay Server project. Other chains
depend on their communities and should be evaluated and operated at your own
risk. Every additional full node increases storage, memory, bandwidth, backup,
and maintenance requirements.

## Available Definitions

| Code | Chain | Lightning options |
|---|---|---|
| `btc` | Bitcoin | CLN, LND, Phoenixd |
| `ltc` | Litecoin | None |
| `grs` | Groestlcoin | CLN, LND |
| `ftc` | Feathercoin | None |
| `dash` | Dash | None |
| `doge` | Dogecoin | None |
| `mona` | Monacoin | None |
| `xmr` | Monero | None |
| `bdx` | Beldex | None |
| `lbtc` | Liquid | None |
| `zec` | Zcash | None |
| `dcr` | Decred | None |

The current source of truth is
[`docker-compose-generator/crypto-definitions.json`](../docker-compose-generator/crypto-definitions.json).
Unknown codes do not select a chain; use empty variables rather than a `none`
code for unused slots.

## Select More Than One Chain

```bash
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="ltc"
. ./btcpay-setup.sh -i
```

When changing an existing deployment, preserve every chain you still want in
the numbered variables. Setup regenerates the stack from the complete current
selection.

## Monero

Monero support uses the community-maintained Monero plugin together with the
node and wallet services provided by this deployment. Select `xmr` before
running setup; for example, to enable Bitcoin and Monero:

```bash
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_CRYPTO2="xmr"
. ./btcpay-setup.sh -i
```

After BTCPay Server starts:

1. In **Server Settings > Manage Plugins**, install the **Monero** plugin and
   restart BTCPay Server when prompted.
2. Create a dedicated Monero wallet for the store. In the store's **Monero**
   wallet settings, enter its primary address, private view key, and restore
   height. Never enter its seed or spend key.
3. Wait for the Monero node to finish syncing and for **Wallet RPC available**
   to show **True**, then enable Monero and select the required confirmation
   policy.

The private view key lets BTCPay generate invoice subaddresses and detect
payments, but not spend the wallet's funds. For screenshots, wallet-specific
instructions, and troubleshooting, see
[Accepting Monero via BTCPay Server](https://sethforprivacy.com/guides/accepting-monero-via-btcpay-server/).

## Chain-specific Considerations

- Monero runs a pruned daemon by default. Its wallet RPC is internal unless
  `opt-monero-expose` binds daemon RPC to host loopback.
- `opt-beldex-expose` is not currently a reliable wallet-RPC exposure path due
  to a service-name mismatch in the fragment. Treat Beldex RPC exposure as
  unsupported until the fragment is corrected and tested.
- Liquid recommends its default pruning fragment automatically.
- The Zcash definition uses an external lightwallet service. The bundled
  full-node fragment does not currently have a supported selection path.
- Decred requires a wallet passphrase through
  `BTCPAY_DCR_WALLET_PASSPHRASE`. Setup does not persist this value; export it
  again before setup, updates, or service recreation.

Adding a chain not present in the definitions is a generator development task;
see [Development](./development.md#add-a-cryptocurrency).
