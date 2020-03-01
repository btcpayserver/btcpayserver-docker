# Pi-Hole support

[Pi-Hole](https://pi-hole.net/) is a black hole for internet advertisement.
It works as a DNS server which blacklist domains tied to advertisement. If you use it as your main DNS server and it detects your query is trying to resolve a domain belonging to an advertisement company, it will resolve the domain to IP `0.0.0.0`, preventing the advertisement to load on any computer using this DNS server.

Note that our pi-hole integration is meant to be used in a **local network**. Please do not try to use this option on a VPS.

## How to use

Let's imagine the local IP of your BTCPay Server is `192.168.1.2`.

1. Connect as root to your server
2. Add pihole as an option to your docker deployment

```bash
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-pihole"
. btcpay-setup.sh -i
```

3. If your server has a firewall, make sure it allow incoming traffic to port `53 (UDP)`.
4. Configure your home router DHCP server to use `192.168.1.2`


From now everytime a device will connect to your local network, they will automatically use pi-hole as a DNS server. Advertisements will go to a black hole for all devices.

## Using the dashboard

Pi-Hole comes with a very nice admin dashboard to monitor its activity.
It is disabled by default. To enable it, you need to configure `PIHOLE_SERVERIP` to the IP of your server:

```bash
PIHOLE_SERVERIP="192.168.1.2"
. btcpay-setup.sh -i
```

If your device is using pi-hole as a DNS server, you should now be able to browse `http://pi.hole/admin` to connect to your dashboard.

You can find the admin password in the logs of pihole:

```bash
docker logs pihole | grep random
```

If the password does not work, you can try to reset the password:
```bash
pihole.sh -a -p
docker restart pihole
```

Then running again
```bash
docker logs pihole | grep random
```

## Make pi-hole the eafult host for the Reverse Proxy Server

As per here: https://github.com/pi-hole/docker-pi-hole#tips-and-tricks adding this will make the experience even more user firendly, blocking more ads.  This will mean, when you visit port 80 with just your IP (eg. 192.168.1.2 etc) for pi-hole, pihole will show as the deafult page.

```bash
REVERSEPROXY_DEFAULT_HOST="pi.hole"
. btcpay-setup.sh -i
```

## Adding custom entry to pi-hole dns

You can easily add your local domains to pi-hole.
Imagine you have a NAS (like synology) on your local network with IP `192.168.1.3`, and you want to access it through `synology.lan`.

```bash
local_dns_list="$(docker volume inspect generated_pihole_datadir -f "{{.Mountpoint}}")/lan.list"
# In most cases this will be /var/lib/docker/volumes/generated_pihole_datadir/_data/lan.list
echo "192.168.1.3 synology.lan" >> "$local_dns_list"
pihole.sh restartdns
```

You can now browse `http://synology.lan` to access your NAS.
