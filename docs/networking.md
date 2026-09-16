# Networking

The normal deployment publishes Nginx on ports 80 and 443. Nginx routes the
configured hosts to BTCPay Server and optional services, while the ACME
companion obtains HTTPS certificates.

## Public HTTPS

For automatic HTTPS:

1. Point the DNS records for `BTCPAY_HOST` at the server.
2. Allow incoming TCP traffic on ports 80 and 443.
3. Keep `BTCPAYGEN_REVERSEPROXY=nginx`.
4. Optionally set `LETSENCRYPT_EMAIL` for expiry notifications.

Port 80 must be reachable for the default ACME HTTP challenge. Changing
`REVERSEPROXY_HTTP_PORT` prevents direct validation unless another network
device forwards public port 80 to it.

`BTCPAY_ADDITIONAL_HOSTS` accepts comma-separated hostnames. By default,
certificates are requested for the primary and additional hosts. Set
`BTCPAY_LETSENCRYPT_HOSTS` to a comma-separated subset, or explicitly set it to
an empty string to disable certificate requests.

## External Reverse Proxy

To terminate HTTPS before the BTCPay host, generate the stack without bundled
Nginx and publish BTCPay Server directly:

```bash
export BTCPAYGEN_REVERSEPROXY="none"
export BTCPAY_HOST="btcpay.example.com"
export BTCPAY_PROTOCOL="https"
export NOREVERSEPROXY_HTTP_PORT="10080"
. ./btcpay-setup.sh -i
```

Forward the external hostname to port 10080 and preserve the `Host`,
`X-Forwarded-Proto`, and client-address headers. Restrict direct access to the
published port.

If the bundled Nginx remains behind another trusted TLS proxy, set
`TRUST_DOWNSTREAM_PROXY=true` only after preventing clients from reaching its
HTTP port directly. This setting trusts forwarded headers and is enabled
automatically by the Cloudflare Tunnel fragment.

## Cloudflare Tunnel

The `opt-add-cloudflared` fragment exposes bundled Nginx through a token-based
Cloudflare Tunnel without opening inbound ports. Cloudflare terminates and can
observe or modify the traffic. Follow the [Cloudflare Tunnel guide](./cloudflare-tunnel.md)
for setup.

## Lightning Ports

Bitcoin CLN and LND publish host TCP port 9735 for peer connections.
Bitcoin CLN also exposes container port 9736 internally for gRPC, but does not
publish it on the host. Phoenixd does not expose a public peer-listening port
through this stack. Open only the host ports required by the implementation you
select.

## Optional Nginx Routes

Fragments declare required routes and optional routes. Required routes are
enabled automatically. Manage optional routes with `btcpay-routes`:

```bash
btcpay-routes show
btcpay-routes add lnd-rest
btcpay-routes add lnd-grpc
btcpay-routes add clightning-rest
btcpay-routes remove lnd-rest
```

The command returns JSON for `show`, `add`, and `remove`. Enabled routes are
stored as relative symlinks under `nginx/enabled-routes` and synchronized during
generation. Changes validate and reload a running Nginx container; a failed
validation or reload is rolled back.

LND's wallet creation, unlock, and password-change methods remain blocked by
Nginx because those methods are not macaroon-protected. Other LND API calls
require the appropriate macaroon.

## Unsafe Exposures

Internal Compose `expose` entries are not host-published ports. Fragments named
`*-expose` deliberately bind additional RPC endpoints, generally to host
loopback. `opt-expose-unsafe` publishes Bitcoin P2P port 8333 and must be used
only on a trusted LAN or behind firewall rules that allow known peers.
