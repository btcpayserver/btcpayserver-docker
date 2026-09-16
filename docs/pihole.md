# Pi-hole

[Pi-hole](https://pi-hole.net/) is a DNS-based network advertisement blocker.

The integration is intended for a **trusted local network**. Do not expose its
DNS service on a public VPS.

## How to use

Let's imagine the local IP of your BTCPay Server is `192.168.1.2`.

Assume the local IP address of the BTCPay Server host is `192.168.1.2`.
Connect as root and enable the fragment:

```bash
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-pihole"
. btcpay-setup.sh -i
```

Allow incoming TCP and UDP traffic on port 53 from the trusted LAN. Configure
the router's DHCP server to advertise `192.168.1.2` as the primary DNS server.

## Using the dashboard

Set `PIHOLE_SERVERIP` to the host's LAN address to enable the dashboard:

```bash
PIHOLE_SERVERIP="192.168.1.2"
. btcpay-setup.sh -i
```

From a device using Pi-hole for DNS, browse to `http://pi.hole/admin`.

Set the admin password:

```bash
pihole.sh setpassword
```
