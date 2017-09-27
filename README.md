# How to use

Mainnet is not support for now, as BTCPay is under development.
Running on TestNet with postgres database:

```
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker
docker-compose up
```

You can then browse http://127.0.0.1:23001/

If you want to refresh the btcpay image up to the latest master, you need to rebuild the image.

```
docker build . -t btcpay --no-cache
```

By default this will connect to a NBXplorer instance hosted by me, on which I can make no promise of avaialability.

