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
4. Configure your home router DHCP server to use `192.168.1.2` as primary DNS server.


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
