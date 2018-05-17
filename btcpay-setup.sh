#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [[ ! -d "Production-NoReverseProxy" ]]; then
   echo "You must run this script from inside the btcpayserver-docker folder" 
   exit 1
fi

if ! git -C . rev-parse
    echo "You must run this script inside the git repository of btcpayserver-docker"
then

function display_help () {
cat <<-END
Usage:
------
    This script must be run as root
    -i : Run install

This script will:

* Install Docker
* Install Docker-Compose
* Setup BTCPay settings
* Make sure it starts at reboot via upstart or systemd
* Add BTCPay utilities in /usr/bin
* Start BTCPay

You can run again this script if you desire to change your configuration.

Make sure you own a domain with DNS record pointing to your website and that port 80 is accessible before running this script.
This will be used to properly setup HTTPS via let's encrypt.

Environment variables:
    BTCPAY_HOST: The hostname of your website (eg. btcpay.example.com)
    LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com, Default:me@example.com)
    NBITCOIN_NETWORK: The type of network to use (eg. mainnet, testnet or regtest. Default: mainnet)
    LIGHTNING_ALIAS: An alias for your lightning network node if used
    BTCPAYGEN_CRYPTO1: First supported crypto currency (eg. btc, ltc, none. Default: btc)
    BTCPAYGEN_CRYPTO2: Second supported crypto currency (eg. btc, ltc, none. Default: empty)
    BTCPAYGEN_CRYPTON: N th supported crypto currency where N is maximum at maximum 9. (eg. btc, ltc. Default: none)
    BTCPAYGEN_REVERSEPROXY: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, none. Default: nginx)
    BTCPAYGEN_LIGHTNING: Lightning network implementation to use (eg. clightning, none)
    ACME_CA_URI: The API endpoint to ask for HTTPS certificate (default: https://acme-v01.api.letsencrypt.org/directory)
END
}

if [ "$1" != "-i" ]; then
    display_help()
    exit 1
fi

: "${LETSENCRYPT_EMAIL:=me@example.com}"
: "${NBITCOIN_NETWORK:=mainnet}"
: "${BTCPAYGEN_CRYPTO1:=btc}"
: "${BTCPAYGEN_REVERSEPROXY:=nginx}"
: "${BTCPAYGEN_LIGHTNING:=none}"
: "${ACME_CA_URI:=https://acme-v01.api.letsencrypt.org/directory}"

ORIGINAL_DIRECTORY=$(pwd)
BTCPAY_BASE_DIRECTORY="$(dirname $(pwd))"
BTCPAY_DOCKER_COMPOSE="$(pwd)/Generated/docker-compose.generated.yml"
BTCPAY_ENV_FILE="$BTCPAY_BASE_DIRECTORY/.env"

echo "
-------SETUP-----------
Parameters passed:
BTCPAY_HOST:$BTCPAY_HOST
LETSENCRYPT_EMAIL:$LETSENCRYPT_EMAIL
NBITCOIN_NETWORK:$NBITCOIN_NETWORK
LIGHTNING_ALIAS:$LIGHTNING_ALIAS
BTCPAYGEN_CRYPTO1:$BTCPAYGEN_CRYPTO1
BTCPAYGEN_CRYPTO2:$BTCPAYGEN_CRYPTO2
BTCPAYGEN_CRYPTO3:$BTCPAYGEN_CRYPTO3
BTCPAYGEN_CRYPTO4:$BTCPAYGEN_CRYPTO4
BTCPAYGEN_CRYPTO5:$BTCPAYGEN_CRYPTO5
BTCPAYGEN_CRYPTO6:$BTCPAYGEN_CRYPTO6
BTCPAYGEN_CRYPTO7:$BTCPAYGEN_CRYPTO7
BTCPAYGEN_CRYPTO8:$BTCPAYGEN_CRYPTO8
BTCPAYGEN_CRYPTO9:$BTCPAYGEN_CRYPTO9
BTCPAYGEN_REVERSEPROXY:$BTCPAYGEN_REVERSEPROXY
BTCPAYGEN_LIGHTNING:$BTCPAYGEN_LIGHTNING
ACME_CA_URI:$ACME_CA_URI
----------------------
Additional exported variables:
BTCPAY_DOCKER_COMPOSE=$BTCPAY_DOCKER_COMPOSE
BTCPAY_BASE_DIRECTORY=$BTCPAY_BASE_DIRECTORY
BTCPAY_ENV_FILE=$BTCPAY_ENV_FILE
----------------------
"

if [ -z "$BTCPAY_HOST" ]; then
    echo "BTCPAY_HOST should not be empty"
    exit 1
fi

if [ -z "$BTCPAYGEN_CRYPTO1" ]; then
    echo "BTCPAYGEN_CRYPTO1 should not be empty"
    exit 1
fi

if [ "$NBITCOIN_NETWORK" != "mainnet" ] && [ "$NBITCOIN_NETWORK" != "testnet" ] && [ "$NBITCOIN_NETWORK" != "regtest" ]; then
    echo "NBITCOIN_NETWORK should be equal to mainnet, testnet or regtest"
fi

export BTCPAY_DOCKER_COMPOSE
export BTCPAY_BASE_DIRECTORY
export BTCPAY_ENV_FILE

# Put the variables in /etc/profile.d when a user log interactively
touch "/etc/profile.d/btcpay-env.sh"
echo "
export BTCPAY_HOST=\"$BTCPAY_HOST\"
export LETSENCRYPT_EMAIL=\"$LETSENCRYPT_EMAIL\"
export NBITCOIN_NETWORK=\"$NBITCOIN_NETWORK\"
export LIGHTNING_ALIAS=\"$LIGHTNING_ALIAS\"
export BTCPAYGEN_CRYPTO1=\"$BTCPAYGEN_CRYPTO1\"
export BTCPAYGEN_CRYPTO2=\"$BTCPAYGEN_CRYPTO2\"
export BTCPAYGEN_CRYPTO3=\"$BTCPAYGEN_CRYPTO3\"
export BTCPAYGEN_CRYPTO4=\"$BTCPAYGEN_CRYPTO4\"
export BTCPAYGEN_CRYPTO5=\"$BTCPAYGEN_CRYPTO5\"
export BTCPAYGEN_CRYPTO6=\"$BTCPAYGEN_CRYPTO6\"
export BTCPAYGEN_CRYPTO7=\"$BTCPAYGEN_CRYPTO7\"
export BTCPAYGEN_CRYPTO8=\"$BTCPAYGEN_CRYPTO8\"
export BTCPAYGEN_CRYPTO9=\"$BTCPAYGEN_CRYPTO9\"
export BTCPAYGEN_LIGHTNING=\"$BTCPAYGEN_LIGHTNING\"
export ACME_CA_URI=\"$ACME_CA_URI\"
export BTCPAY_DOCKER_COMPOSE=\"$BTCPAY_DOCKER_COMPOSE\"
export BTCPAY_BASE_DIRECTORY=\"$BTCPAY_BASE_DIRECTORY\"
export BTCPAY_ENV_FILE=\"$BTCPAY_ENV_FILE\"" > /etc/profile.d/btcpay-env.sh
chmod +x /etc/profile.d/btcpay-env.sh
echo "BTCPay Server environment variables successfully saved in /etc/profile.d/btcpay-env.sh"

if ! [ -x "$(command -v docker)" ]; then
    apt-get update 2>error
    apt-get install -y \
        curl \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        2>error
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
    apt-get update
    if apt-get install -y docker-ce ; then
        echo "Docker installed"
    else
        if [ $(lsb_release -cs) == "bionic" ]; then
            # Bionic not in the repo yet, see https://linuxconfig.org/how-to-install-docker-on-ubuntu-18-04-bionic-beaver
            add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            artful \
            stable"
            apt-get update
            apt-get install -y docker-ce
        fi
    fi
else
    echo "docker is already installed"
fi

# Install docker-compose
if ! [ -x "$(command -v docker-compose)" ]; then
    apt-get update 2>error
    apt-get install -y \
        curl \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        2>error
    curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "docker-compose is already installed"
fi

# Set .env file
touch $BTCPAY_ENV_FILE
echo "
BTCPAY_HOST=$BTCPAY_HOST
ACME_CA_URI=$ACME_CA_URI
NBITCOIN_NETWORK=$NBITCOIN_NETWORK
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
LIGHTNING_ALIAS=$LIGHTNING_ALIAS" > $BTCPAY_ENV_FILE
echo "BTCPay Server docker-compose parameters saved in $BTCPAY_ENV_FILE"

# Generate the docker compose in BTCPAY_DOCKER_COMPOSE
. ./build.sh

cd BTCPAY_BASE_DIRECTORY

# Schedule for reboot
if [ -d "/etc/systemd/system" ]; then # Use systemd

echo "Adding btcpayserver.service to systemd"
echo "
[Unit]
Description=BTCPayServer service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" up -d'
ExecStop=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" stop'
ExecReload=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" restart'

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/btcpayserver.service

echo "BTCPay Server systemd configured in /etc/systemd/system/btcpayserver.service"
systemctl daemon-reload
systemctl enable btcpayserver
systemctl start btcpayserver
echo "BTCPay Server started"
else # Use upstart
echo "Using upstart"
echo "
# File is saved under /etc/init/start_containers.conf
# After file is modified, update config with : $ initctl reload-configuration

description     \"Start containers (see http://askubuntu.com/a/22105 and http://askubuntu.com/questions/612928/how-to-run-docker-compose-at-bootup)\"

start on filesystem and started docker
stop on runlevel [!2345]

# if you want it to automatically restart if it crashes, leave the next line in
# respawn # might cause over charge

script
    . /etc/profile.d/btcpay-env.sh
    cd \"`dirname \$BTCPAY_ENV_FILE`\"
    docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" up -d
end script" > /etc/init/start_containers.conf
    echo "BTCPay Server upstart configured in /etc/init/start_containers.conf"
    initctl reload-configuration
    docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d 
    echo "BTCPay Server started"
fi


find "$ORIGINAL_DIRECTORY" -name "*.sh" -exec chmod +x {} \;
find "$ORIGINAL_DIRECTORY" -name "*.sh" -exec ln -s {} /usr/bin \;
