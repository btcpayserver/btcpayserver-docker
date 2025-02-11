# Shopify-app

Shopify app allows you to customize the checkout experience of your store in shopify to allow your customers to pay via BTCPay Server.

First, install the fragment.
```bash
BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-shopify"
. btcpay-setup.sh -i
```

Second, create an all on [Shopify Partner](https://partners.shopify.com/). Choose `Create app manually`.

In the overview menu of the app page, note the `Client ID` and the `Client secret`.
Then go into `Configuration` and note the `App handle`.

Back in your server, run `shopify-set-config.sh`.

Then copy and paste the requested information.

Finally run `shopify.sh app deploy`.