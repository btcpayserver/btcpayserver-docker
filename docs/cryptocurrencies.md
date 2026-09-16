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
[`docker-compose-generator/crypto-definitions.json`](https://github.com/btcpayserver/btcpayserver-docker/blob/master/docker-compose-generator/crypto-definitions.json).
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

## Chain-specific Considerations

- Monero runs a pruned daemon by default. Its wallet RPC is internal unless
  `opt-monero-expose` binds daemon RPC to host loopback.
- Beldex wallet RPC is internal unless `opt-beldex-expose` is selected.
- Liquid recommends its default pruning fragment automatically.
- The default Zcash definition uses an external lightwallet service. The
  separate full-node fragment is resource intensive and intended for advanced
  testing.
- Decred requires a wallet passphrase through
  `BTCPAY_DCR_WALLET_PASSPHRASE`.

Adding a chain not present in the definitions is a generator development task;
see [Development](./development.md#add-a-cryptocurrency).
