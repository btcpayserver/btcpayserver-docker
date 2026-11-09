# Pi-hole

[Pi-hole](https://pi-hole.net/) is a DNS-based network advertisement blocker.

The integration is intended only for a **trusted local network**. The fragment
publishes TCP and UDP port 53 on every host interface by default and configures
Pi-hole to listen on all container interfaces. Do not enable it on a public VPS
or any host where WAN clients can reach port 53; an exposed recursive resolver
can be abused.

Before enabling the fragment, confirm that host port 53 is unused and enforce a
default-deny firewall rule that permits it only from the trusted LAN. Docker
published ports can bypass simple UFW rules, so use a provider firewall or a
verified Docker-aware host policy such as `DOCKER-USER`. Verify from outside the
LAN that both TCP and UDP port 53 are blocked before advertising Pi-hole through
DHCP.

## How to use

Assume the local IP address of the BTCPay Server host is `192.168.1.2`.
From a root login shell on an existing BTCPay Server Docker deployment, enable
the fragment:

```bash
btcpay-fragments add opt-add-pihole
```

To restrict host DNS exposure, set `PIHOLE_DNS_BIND` before enabling the fragment:

```bash
export PIHOLE_DNS_BIND="192.168.1.2:53"
btcpay-fragments add opt-add-pihole
```

The value is the host-side `[IP_ADDRESS:]PORT` binding, shared by TCP and UDP.
Unset or empty defaults to `53`, preserving Docker's all-interface binding.
Use brackets for IPv6, for example `[fd00::2]:53`. This setting controls Docker's
published DNS ports, not the web dashboard or Pi-hole's container-side listening
mode. It is independent of `PIHOLE_SERVERIP`.

For an existing deployment, export the value and source `btcpay-setup.sh -i`
from the deployment directory to persist and apply it.

Configure the router's DHCP server to advertise `192.168.1.2` as the DNS server.
Advertising another resolver may allow clients to bypass Pi-hole.

## Using the dashboard

Set `PIHOLE_SERVERIP` to the host's LAN address so Pi-hole returns the correct
address for its local dashboard hostname. This variable does not enable or
disable the dashboard:

```bash
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
export PIHOLE_SERVERIP="192.168.1.2"
. ./btcpay-setup.sh -i
```

From a device using Pi-hole for DNS, browse to `http://pi.hole/admin`.

Set the admin password:

```bash
pihole.sh setpassword
```
