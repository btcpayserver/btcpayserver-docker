# Chatwoot support

[Chatwoot](https://www.chatwoot.com/) is a customer support tool for instant messaging channels which can help businesses provide exceptional customer support.

## How to use

1. Connect as root to your server
2. create chatwoot configuration file where `{CONFIG DATA HERE}` is replaced by settings from [here](https://www.chatwoot.com/docs/environment-variables)

```bash
sudo su -
cd btcpayserver-docker
cat >> Generated/chatwoot-config.env <<EOL
{CONFIG DATA HERE}
{CONFIG DATA HERE}
EOL
```
3. Add chatwoot as an option to your BTCPay deployment and set the host to use (point DNS to server as well)

```bash
CHATWOOT_HOST="chatwoot.xpayserver.com"
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-chatwoot"
. btcpay-setup.sh -i

```
4. Wait for BTPay to be online and then create the database for chatwoot

```bash
docker exec -ti chatwoot sh -c "export DISABLE_DATABASE_ENVIRONMENT_CHECK=1 && bundle exec rails db:reset"
```
4. Go to chatwoot website at https://chatwoot.xpayserver.com and set up.

