# Chatwoot

[Chatwoot](https://www.chatwoot.com/) is a self-hosted customer-support and
messaging application.

## Installation

Create `Generated/chatwoot-config.env` with the settings required by the
[Chatwoot environment reference](https://www.chatwoot.com/docs/environment-variables).
The file is ignored by Git.

```bash
sudo su -
cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
editor Generated/chatwoot-config.env
```
Point a dedicated hostname at the server, then enable the fragment:

```bash
export CHATWOOT_HOST="chatwoot.example.com"
btcpay-fragments add opt-add-chatwoot
```
After the services start, initialize the Chatwoot database:

```bash
docker exec -ti chatwoot sh -c \
  "bundle exec rails db:prepare"
```
Open `https://chatwoot.example.com` to finish setup.

The bundled fragment uses an old fixed Chatwoot release. Review its image and
configuration before enabling it on a production deployment.
