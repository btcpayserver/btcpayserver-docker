# How to use docker-compose with Traefik

Traefik is a modern reverse proxy aimed towards applications running through container orchestrators. 

Some of the benefits of using Traefik over NGinx are:
* Real-time configuration changes - no need to reload the proxy
* Auto discovery and configuration of services through a vast amount of container orchestrators.
* Built-in official support for Let's Encrypt SSL with certificate auto-renewal

## Traefik Specific Environment Variables

* `BTCPAYGEN_REVERSEPROXY` to `traefik`.
* `LETSENCRYPT_EMAIL`: Optional, The email Let's Encrypt will use to notify you about certificate expiration.
* `BTCPAYGEN_ADDITIONAL_FRAGMENTS`: In the case that you have an already deployed traefik container, you can use the fragment `traefik-labels` which will tag the btcpayserver service with the needed labels to be discovered.


![Architecture](Production.png)