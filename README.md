# How to use

Mainnet is not support for now, as BTCPay is under development.
Running on TestNet:

```
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker
docker build . -t btcpay
docker run -p 23001:23001 -ti btcpay
```

You can then browse http://127.0.0.1:23001/
By default this will connect to a NBXplorer instance hosted by me, on which I can make no promise of avaialability.

