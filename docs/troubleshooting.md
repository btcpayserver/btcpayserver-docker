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
docker-compose -f "$BTCPAY_DOCKER_COMPOSE" config
```

The generated configuration should parse without errors. A stopped or
restarting service usually has the most useful immediate log output.

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
```

A 503 response often means Nginx received the request but did not find a route
for its hostname. Confirm `BTCPAY_HOST`, and set `REVERSEPROXY_DEFAULT_HOST` only
when requests with unrecognized hosts should reach BTCPay Server.

If another proxy terminates HTTPS, confirm it preserves the `Host` and
`X-Forwarded-Proto` headers. See [Networking](./networking.md).

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
- The current repository commit from `git rev-parse HEAD`

Ask deployment questions in the
[community chat](https://chat.btcpayserver.org/). Use the
[GitHub issue tracker](https://github.com/btcpayserver/btcpayserver-docker/issues)
for reproducible defects in this repository.
