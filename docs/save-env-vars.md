# Save Environment Variables to Script

Environment Variables are lost upon logging out of the server. This means that any change to our config requires us to export ALL variables again before running `. ./btcpay-setup.sh -i`.

One solution to this might be simply saving your config as a `.txt` file and copying over from there, but this does not alleviate us of the manual labor of pasting each line.

My solution: save them as a script that we will run using `source` before runnning `btcpay-setup.sh`.

## Basic Way
From the [main docker deployment page](./README.md#full-installation-for-technical-users) our initial setup will look like this:

```bash
# Login as root
sudo su -

# Create a folder for BTCPay
mkdir BTCPayServer
cd BTCPayServer

# Clone this repository
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

# Run btcpay-setup.sh with the right parameters
export BTCPAY_HOST="btcpay.EXAMPLE.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAY_ENABLE_SSH=true
. ./btcpay-setup.sh -i

exit
```

### Updating
SSH into the server, log in as root and navigate to the `btcpayserver-docker` folder.
```bash
# Login as root
sudo su -

# Navigate to directory
cd BTCPayServer/btcpayserver-docker/

# export ALL environment variables fresh because they didn't stick from the first time.
export BTCPAY_HOST="btcpay.EXAMPLE.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAY_ENABLE_SSH=true
[[ "$REVERSEPROXY_DEFAULT_HOST" ]] && REVERSEPROXY_DEFAULT_HOST="$BTCPAY_HOST"
export CLOUDFLARE_TUNNEL_TOKEN="<YOUR_TOKEN_HERE>"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-cloudflared"
export BTCPAYGEN_EXCLUDE_FRAGMENTS="$BTCPAYGEN_EXCLUDE_FRAGMENTS;nginx-https"

# build again
. ./btcpay-setup.sh -i
```

## Script Solution
Ours will look like this:

```bash
# Login as root
sudo su -

# Create a folder for BTCPay
mkdir BTCPayServer
cd BTCPayServer

# Clone this repository
git clone https://github.com/btcpayserver/btcpayserver-docker
cd btcpayserver-docker

# Create and edit our custom script
nano btcpay.cust-env.sh
```

In nano:
```bash
# modify these to your custom setup, for example adding options for cloudflare tunnel support
export BTCPAY_HOST="btcpay.EXAMPLE.com"
export NBITCOIN_NETWORK="mainnet"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAY_ENABLE_SSH=true
```
Save this by using CTRL+X, Y and Enter.

Build the server:
```bash
# load the environment variables to your current session
source ./btcpay.cust-env.sh

# build
. ./btcpay-setup.sh -i
```

### Updating with the script

So you logged out after building your very own BTCPay server implementation. 
Things are going smoothly but now you find that you need to update the configuration to add support for a feature you hadn't originally implemented.
For this example, I'll add a cloudflare tunnel to the server. Keep in mind, you'll need to follow the [docs](./docs/cloudflare-tunnel.md) regarding the cloudflare website which I won't reproduce here.

1. Follow the above steps to login as root and navigate to the `btcpayserver-docker` directory.

2. Stop all btcpay related docker containers. You can use docker ps to make sure that these are the correct names for your containers. Modify accordingly.
```bash
docker stop nginx-gen btcpayserver_bitcoind nginx generated_btcpayserver_1 generated_nbxplorer_1 tor-gen generated_postgres_1 tor
```

3. Follow the [docs](./docs/cloudflare-tunnel.md) to create the cloudflare service on their website. Then, update the environment script file.
```bash
# edit the file
nano btcpay.cust-env.sh

# Add these lines to the end of the file. Don't forget to modify the cloudflare tunnel token.
[[ "$REVERSEPROXY_DEFAULT_HOST" ]] && REVERSEPROXY_DEFAULT_HOST="$BTCPAY_HOST"
export CLOUDFLARE_TUNNEL_TOKEN="<YOUR_TOKEN_HERE>"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="$BTCPAYGEN_ADDITIONAL_FRAGMENTS;opt-add-cloudflared"
export BTCPAYGEN_EXCLUDE_FRAGMENTS="$BTCPAYGEN_EXCLUDE_FRAGMENTS;nginx-https"
```
Again, saving the file using CTRL+X, Y and Enter.

4. Rebuild the server. Fun fact: the bitcoin node is unaffected and you won't have to do another IBD :D

Notice how the build process every time is just two lines with your variables saved safely in a file where you can view/modify them at will.
```bash
# load the environment variables to your current session
source ./btcpay.cust-env.sh

# build
. ./btcpay-setup.sh -i
```
