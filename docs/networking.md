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
certificates are requested for the primary (`BTCPAY_HOST`) and additional hosts (`BTCPAY_ADDITIONAL_HOSTS`). Set
`BTCPAY_LETSENCRYPT_HOSTS` to a comma-separated subset, or explicitly set it to
an empty string to disable certificate requests.

## External Reverse Proxy

To terminate HTTPS on an existing reverse proxy, keep the bundled Nginx for
BTCPay's internal routing but disable its HTTPS companion:

```bash
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAY_HOST="btcpay.example.com"
export BTCPAY_PROTOCOL="https"
export TRUST_DOWNSTREAM_PROXY="true"
. ./btcpay-setup.sh -i
# Disable the HTTPS companion after setup saves the proxy settings above.
btcpay-fragments exclude nginx-https
```

The external proxy must preserve the original host and HTTPS scheme so BTCPay
generates correct URLs. Replace `BTCPAY_SERVER_IP` with an address through which
the external proxy can reach the BTCPay host. The examples below assume the
certificate is already provisioned on the external server.

If the external proxy runs on the BTCPay host, set
`REVERSEPROXY_HTTP_PORT=10080` and use port `10080` instead of `80` below.

### Nginx

```nginx
# Add this map once inside the http block, outside any server block.
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name btcpay.example.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name btcpay.example.com;

    ssl_certificate /etc/letsencrypt/live/btcpay.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/btcpay.example.com/privkey.pem;

    client_max_body_size 100M;

    # Some signing workflows use large request and response headers.
    client_header_buffer_size 500k;
    large_client_header_buffers 4 500k;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;

    location / {
        proxy_pass http://BTCPAY_SERVER_IP:80;
        proxy_http_version 1.1;
        proxy_buffering off;

        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Proxy "";
    }
}
```

Replace the hostname and certificate paths, then validate and reload Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Apache

Enable the required modules on Debian-based systems:

```bash
sudo a2enmod headers proxy proxy_http ssl
```

Apache 2.4.47 or later can proxy HTTP and WebSocket traffic through
`mod_proxy_http`:

```apacheconf
<VirtualHost *:80>
    ServerName btcpay.example.com
    Redirect permanent / https://btcpay.example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName btcpay.example.com

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/btcpay.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/btcpay.example.com/privkey.pem

    ProxyRequests Off
    ProxyPreserveHost On
    ProxyAddHeaders On
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    RequestHeader unset Proxy early

    ProxyPass / http://BTCPAY_SERVER_IP:80/ upgrade=websocket
    ProxyPassReverse / http://BTCPAY_SERVER_IP:80/

    LimitRequestBody 104857600

    # Some signing workflows use large request headers.
    LimitRequestLine 500000
    LimitRequestFieldSize 500000
</VirtualHost>
```

Replace the hostname and certificate paths, then validate and reload Apache:

```bash
sudo apachectl configtest && sudo systemctl reload apache2
```

Firewall Nginx's HTTP port so only the external proxy can connect. This
restriction is required because `TRUST_DOWNSTREAM_PROXY=true` accepts incoming
`X-Forwarded-*` headers as authoritative. Never expose this unencrypted,
trusted backend port publicly.

## Cloudflare Tunnel

The `opt-add-cloudflared` fragment exposes bundled Nginx through a token-based
Cloudflare Tunnel without opening inbound ports. Cloudflare terminates and can
observe or modify the traffic. Follow the [Cloudflare Tunnel guide](./cloudflare-tunnel.md)
for setup.

## Lightning Ports

Bitcoin CLN and LND publish host TCP port 9735 for peer connections.
Groestlcoin CLN and LND publish host TCP port 9736.
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

<a id="expose-bitcoin-lnd-apis"></a>

### LND REST and gRPC APIs

The `lnd-rest` and `lnd-grpc` routes are available when Bitcoin LND and the
bundled Nginx reverse proxy are selected. They are disabled by default. No
additional Compose fragment or host port is required.

Enable only the API required by the external client:

```bash
btcpay-routes add lnd-rest
btcpay-routes add lnd-grpc
```

To enable or disable both together:

```bash
btcpay-routes add lnd-rest lnd-grpc
btcpay-routes remove lnd-rest lnd-grpc
```

Use `btcpay-routes show` to check which routes are enabled. With
`BTCPAY_HOST=btcpay.example.com`, the public endpoints are:

- REST: `https://btcpay.example.com/lnd-rest/btc/`
- gRPC: `btcpay.example.com:443` with TLS

After Bitcoin is synchronized, open **Server Settings > Services** in BTCPay
Server and select **LND (REST)** or **LND (gRPC)** for the endpoint, macaroons,
and temporary QR-code configuration. REST clients send the macaroon in the
`Grpc-Metadata-macaroon` header; gRPC clients use the `macaroon` metadata key.
The public endpoint uses the HTTPS certificate for `BTCPAY_HOST`, not LND's
internal TLS certificate.

Macaroons grant control over the Lightning node. Use the least-privileged
macaroon supported by the client, protect it as a secret, and avoid distributing
the admin macaroon unless full node control is required. Nginx blocks LND's
unauthenticated wallet creation, unlocking, password-change, and state methods.
Other calls still require an appropriate macaroon.

These routes do not publish LND's internal ports `8080` or `10009` on the host;
traffic passes through the configured HTTPS port, normally `443`.

If another reverse proxy is placed in front of the bundled Nginx, it must also
forward the enabled route. The REST route uses regular HTTPS forwarding. The
gRPC route requires the external proxy to support HTTP/2 gRPC forwarding; the
generic external Nginx and Apache examples above only configure HTTP and
WebSocket forwarding.

## Unsafe Exposures

Internal Compose `expose` entries are not host-published ports. Fragments named
`*-expose` deliberately bind additional RPC endpoints, generally to host
loopback. `opt-expose-unsafe` publishes Bitcoin P2P port 8333 and must be used
only on a trusted LAN or behind firewall rules that allow known peers.
