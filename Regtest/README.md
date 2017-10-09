# About this docker-compose

This docker-compose shows how to configure postgres, bitcoind, NBXplorer and BTCPay on regtest.

It exposes BTCPay on the host address http://localhost:8080/.

It also exposes Bitcoin Core RPC which you can access through port 8081:

To access it, you can use:
On Powershell:

```
bitcoin-cli -conf="$pwd/bitcoin.conf" getblockcount
```

On Linux:

```
bitcoin-cli -conf="$pwd/bitcoin.conf" getblockcount
```