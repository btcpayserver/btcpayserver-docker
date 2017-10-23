# About this docker-compose

This docker-compose shows how to configure postgres, bitcoind, NBXplorer and BTCPay on regtest.

It exposes BTCPay on the host address http://localhost:8080/.

If you need to access bitcoind RPC, you can use bitcoin-cli inside the container:

On Powershell:
```
.\docker-bitcoin-cli getblockcount
```

On Linux:
```
docker exec -ti btcpayserver_regtest_bitcoind bitcoin-cli -regtest -conf="/data/bitcoin.conf" -datadir="/data" getblockcount
```