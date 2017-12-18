# How to use

Here is BTCPay Architecture

![Architecture](https://github.com/btcpayserver/btcpayserver-doc/raw/master/img/Architecture.png)

As you can see, it depends on several piece of infrastructure, mainly NBXplorer, Postgres, and Bitcoin Core.
Setting up the dependencies might be time consuming, this repository is meant to give working example of docker-compose file which will setup everything for you.

This assume you already know how docker-compose works.

Used docker image used [BTCPayServer](https://hub.docker.com/r/nicolasdorier/btcpayserver/), [NBXplorer](https://hub.docker.com/r/nicolasdorier/nbxplorer/), [Bitcoin Core](https://hub.docker.com/r/nicolasdorier/docker-bitcoin/) and [Postgres](https://hub.docker.com/_/postgres/).

The [Regtest](Regtest) docker-compose is used for local testing.

The [Production](Production) docker-compose is used for production environment. It is using NGinx as a reverse proxy and [Let's Encrypt and DockerGen](https://github.com/gilyes/docker-nginx-letsencrypt-sample) to automatically configured HTTPS.

You can provision a production BTCPay Server on Azure via this button:

[![Deploy to Azure](https://azuredeploy.net/deploybutton.svg)](https://deploy.azure.com/?repository=https://github.com/btcpayserver/btcpayserver-azure?ptmpl=parameters.azuredeploy.json)