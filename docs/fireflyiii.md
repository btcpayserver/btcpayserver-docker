# Firefly III support

[Firefly III](https://www.firefly-iii.org/)  is a self-hosted financial manager.
It can help you keep track of expenses, income, budgets and everything in between. It supports credit cards, shared household accounts and savings accounts. It’s pretty fancy. You should use it to save and organise money.

## How to use

1. Connect as root to your server
2. Configure a domain's DNS to point to your server ip. e.g. `firefly.yourserver.org`
3. Add fireflyiii as an option to your docker deployment

```bash
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-fireflyiii"
FIREFLY_HOST="firefly.yourserver.org"
. btcpay-setup.sh -i
. ./Tools/fireflyiii/init.sh
```

4. Access Firefly III at `firefly.yourserver.org` and create your admin account.
