# Cloudflare tunnel support

If your server is on a local network, how can you expose it to the internet?

Traditionally, the solution to this problem is either:
* Configure correctly your firewall and your internet router (NAT) to accept incoming traffic
* Use Tor
* Setup a SSH reverse tunnel to a public VPS

The challenge with the first solution si that there is no unified way to do it. Every local network have their own way to do.
On top of it, it may not even work: internet server providers are may block incoming traffic, or they might use dynamic IPs, meaning you need to setup a [dyndns service](https://docs.btcpayserver.org/Deployment/DynamicDNS/) to update the DNS record automatically when the IP change.

The challenges with the second solution are that Tor has very low latency, so your server will feel sluggish and unreliable and you would need a Tor enabled browser to access it. (such as Brave or Tor Browser)

The third solution is technically challenging and isn't free, as you need to pay for a VPS.

Cloudflare tunnel offer an alternative to those solutions without the downsides.
With cloudflare tunnel, you will enjoy low latency access to your server, on clearnet and WITHOUT the need to configure your firewall, internet router, dynamic dns and on any internet service provider. For free.

You still need to configure the tunnel correctly, and this documentation will guide you through it.

## How to use?

First we are going to create the tunnel on Cloudflare.

1. You need to [create an account on Cloudflare](https://cloudflare.com/).
2. Enable Cloudflare for your domain name. For namecheap, [follow this tutorial](https://www.namecheap.com/support/knowledgebase/article.aspx/9607/2210/how-to-set-up-dns-records-for-your-domain-in-cloudflare-account/).
3. After you've added the DNS and is propagated,  go to [Zero Trust](https://dash.teams.cloudflare.com/) option on the left menu, go to `access`, then click `tunnels`.
4. Click `create tunnel` button, give it a name
5. In `Choose your environment`, click on docker and copy your token, you will need it later (the string after `--token`, as shown in the following screenshot)
![](./img/Cloudflare-Tunnel-Token.png)
6. Click on the `Next` button
7. Enter your subdomain, select your domain in the list. Then in `Service` select `HTTP` and enter `localhost`.
8. In your the SSH session of your server, add cloudflare tunnel by running the following script. (replace `<YOUR_TOKEN_HERE>` by what you copied in step `5.`, and also replace `<YOUR_DOMAIN_HERE>` with the domain you entered in steps `7.`)
```bash
BTCPAY_HOST="<YOUR_DOMAIN_HERE>"
CLOUDFLARE_TUNNEL_TOKEN="<YOUR_TOKEN_HERE>"
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-cloudflared"
BTCPAYGEN_EXCLUDE_FRAGMENTS="$BTCPAYGEN_EXCLUDE_FRAGMENTS;nginx-https"
. btcpay-setup.sh -i
```

Now you should be able to access your server from internet!

## Known error

### Error 503

If you get error 503, make sure `BTCPAY_HOST` is set to your domain name and run `. btcpay-setup.sh -i` again.