# About this docker-compose

This docker-compose shows how to configure postgres, bitcoind, NBXplorer and BTCPay on regtest.

It exposes BTCPay on the host address http://localhost:8080/.

It also exposes Bitcoin Core RPC which you can access through port 8081:

```
bitcoin-cli -regtest -rpcport=8081 -rpcpassword=DwubwWsoo3 -rpcuser=ceiwHEbqWI83 getblockcount
```