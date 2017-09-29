# How to use

Here is BTCPay Architecture

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

As you can see, it depends on several piece of infrastructure, mainly NBXplorer, Postgres, and Bitcoin Core.
Setting up the dependencies might be time consuming, this repository is meant to give working example of docker-compose file which will setup everything for you.

This assume you already know how docker-compose works.

Used docker image used [BTCPayServer](https://hub.docker.com/r/nicolasdorier/btcpayserver/), [NBXplorer](https://hub.docker.com/r/nicolasdorier/nbxplorer/), [Bitcoin Core](https://hub.docker.com/r/nicolasdorier/docker-bitcoin/) and [Postgres](https://hub.docker.com/_/postgres/).

The revelant volumes are:

* /datadir in NBXplorer
* /datadir in BTCPayServer
* /data in Bitcoin
* /var/lib/postgresql/data in Postgres

