# Troubleshooting

This guide covers the Docker deployment. For application-level problems, also
check the [BTCPay Server troubleshooting guide](https://docs.btcpayserver.org/Troubleshooting/).

## Confirm the Saved Environment

Start a root login shell and verify the deployment paths:

```bash
sudo su -
printf 'Base: %s\nCompose: %s\nEnvironment: %s\n' \
  "$BTCPAY_BASE_DIRECTORY" "$BTCPAY_DOCKER_COMPOSE" "$BTCPAY_ENV_FILE"
```

On Linux, the profile is stored in `/etc/profile.d/btcpay-env.sh`. If variables
are empty, start a new login shell or source that file.

## Check Container State

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" config --quiet
```

The generated configuration should parse without errors. A stopped or
restarting service usually has the most useful immediate log output.
Do not publish full `docker-compose config` output without careful redaction;
interpolated environment values can include tunnel tokens and add-on passwords.

## Inspect Logs

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs --timestamps
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs --tail 200 btcpayserver
docker logs --tail 200 nginx
```

Follow one service while reproducing a problem:

```bash
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs -f btcpayserver
```

After an update, inspect the compressed pre-update snapshots described in
[Updating](./updating.md#archived-update-logs).

## Ubuntu 26.04: Containers Hang with `gosu` at 100% CPU

After an Ubuntu 26.04 upgrade, PostgreSQL, Bitcoin Core, or Monero containers
may appear `Up` but never start their daemons. Logs can be empty, `gosu` consumes
about 100% CPU, and BTCPay Server restarts because its database is unavailable.
Restarting the stack does not resolve this.

On affected kernels, AppArmor stacks the container's profile as
`docker-default//&unconfined`. Docker's affected default profile only permits
signals between processes labeled `docker-default`, so it denies signals
between the container's own processes. Check the host's kernel log:

```bash
journalctl -k --grep='apparmor="DENIED".*operation="signal"'
```

A matching denial includes `comm="gosu"` and
`peer="docker-default//&unconfined"`. Do not apply this workaround for unrelated
startup failures. See [BTCPay issue #1257](https://github.com/btcpayserver/btcpayserver-docker/issues/1257)
and the [upstream Docker report](https://github.com/moby/moby/issues/54099).
The [upstream profile fix](https://github.com/moby/profiles/pull/58) was merged
on November 19, 2026; prefer a Docker package containing that fix when available
for your distribution.

### Temporary Workaround

If a fixed Docker package is not yet available, a
[custom fragment](./customization.md#create-a-custom-fragment) can disable
AppArmor **only for the affected services**. Those containers lose AppArmor
confinement; seccomp, capability restrictions, and namespaces remain in place.
Do not disable AppArmor host-wide or grant all capabilities.

As root, in the deployment checkout, list the configured service names:

```bash
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" config --services
```

Create `docker-compose-generator/docker-fragments/opt-apparmor-gosu.custom.yml`
with the following content. **Omit services that are not in your deployment or
are not affected**; an override for an absent service can produce an invalid
Compose configuration. Other coin daemons using `gosu` may need their own
entry if they show the same denial.

```yaml
services:
  postgres:
    security_opt:
      - apparmor=unconfined
  bitcoind:
    security_opt:
      - apparmor=unconfined
  monerod:
    security_opt:
      - apparmor=unconfined
  monerod_wallet:
    security_opt:
      - apparmor=unconfined
```

Apply it during a maintenance window; this regenerates the configuration and
recreates affected containers, briefly interrupting service:

```bash
btcpay-fragments add opt-apparmor-gosu.custom
```

Check [container state](#check-container-state) and [logs](#inspect-logs) to
confirm the daemons actually start, rather than relying on Docker's `Up` state.
Confirm synchronization in BTCPay Server before accepting payments.

After installing a Docker package containing the upstream fix, remove the
workaround to recreate containers with normal AppArmor confinement:

```bash
btcpay-fragments remove opt-apparmor-gosu.custom
```

Verify startup and kernel logs again. The now-unused custom file can be deleted.

## Check Bitcoin Synchronization

```bash
bitcoin-cli.sh getblockchaininfo
bitcoin-cli.sh getnetworkinfo
```

Compare the reported block height with a current public source. BTCPay Server
cannot reliably detect payments until Bitcoin Core and NBXplorer are caught up.

## Check Nginx and HTTPS

Confirm DNS points to this host and ports 80/443 reach it. Then validate Nginx:

```bash
docker exec nginx nginx -t
docker logs --tail 200 nginx
btcpay-routes show
curl --show-error --silent --output /dev/null "https://$BTCPAY_HOST/"
```

When using the bundled automatic HTTPS setup, also inspect its ACME companion:

```bash
docker logs --tail 200 letsencrypt-nginx-proxy-companion
```

Setup can exit successfully even if certificate issuance fails. Check this
output for the configured hostname and use the `curl` result as an independent
check that its certificate is valid. Do not bypass certificate validation with
`curl --insecure`.

A 503 response often means Nginx received the request but did not find a route
for its hostname. Confirm `BTCPAY_HOST`, and set `REVERSEPROXY_DEFAULT_HOST` only
when requests with unrecognized hosts should reach BTCPay Server.

If another proxy terminates HTTPS, confirm it preserves the `Host` and
`X-Forwarded-Proto` headers. See [Networking](./networking.md).

### "Your access to BTCPay Server is over an unsecured network"

If HTTPS is terminated by an external reverse proxy, ensure it sends
`X-Forwarded-Proto: https`, then reconfigure BTCPay Server to trust the proxy:

```bash
export TRUST_DOWNSTREAM_PROXY="true"
. ./btcpay-setup.sh -i
```

Only enable this when the BTCPay host's HTTP port is accessible exclusively
through the trusted reverse proxy. See [External Reverse
Proxy](./networking.md#external-reverse-proxy).

## Restart the Stack

```bash
btcpay-restart.sh
```

`btcpay-up.sh` includes a recovery check for an Nginx container that failed
during recreation. If Nginx remains down, the command prints its latest logs.

## Collect Diagnostics Before Requesting Help

Include:

- The exact command and error
- The selected network, cryptocurrencies, Lightning implementation, and
  additional fragments
- `docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps`
- Relevant service logs with secrets and customer information removed
- Whether DNS, ports, proxies, or firewall rules recently changed
- The current repository commit from
  `git -C "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker" rev-parse HEAD`

Ask deployment questions in the
[community chat](https://chat.btcpayserver.org/). Use the
[GitHub issue tracker](https://github.com/btcpayserver/btcpayserver-docker/issues)
for reproducible defects in this repository.
