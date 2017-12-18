# How to use

This repository is hosting different docker-compose which can be used to facilitate deployment of BTCPay Server.

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

As you can see, it depends on several piece of infrastructure, mainly:

* A lightweight block explorer (NBXplorer), 
* A database (Postgres, or SQLite),
* A full node (Bitcoin Core)

Setting up the dependencies might be time consuming, this repository is meant to give working example of `docker-compose` file which will setup everything for you.

Used docker image used [BTCPayServer](https://hub.docker.com/r/nicolasdorier/btcpayserver/), [NBXplorer](https://hub.docker.com/r/nicolasdorier/nbxplorer/), [Bitcoin Core](https://hub.docker.com/r/nicolasdorier/docker-bitcoin/) and [Postgres](https://hub.docker.com/_/postgres/).

The [Regtest](Regtest) `docker-compose` can be used for local testing.

The [Production](Production) `docker-compose` is used for production environment. It is using NGinx as a reverse proxy and [Let's Encrypt and DockerGen](https://github.com/gilyes/docker-nginx-letsencrypt-sample) to automatically configured HTTPS.

The production `docker-compose` is used under the hood to deploy an instance of BTCPay on Microsoft Azure in one click:

[![Deploy to Azure](https://azuredeploy.net/deploybutton.svg)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbtcpayserver%2Fbtcpayserver-azure%2Fmaster%2Fazuredeploy.json)