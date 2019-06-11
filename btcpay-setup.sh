#!/bin/bash

if [ "$0" = "$BASH_SOURCE" ]; then
    echo "This script must be sourced \". btcpay-setup.sh\"" 
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root after running \"sudo su -\"" 
   return
fi

# Verify we are in right folder. If we are not, let's go in the parent folder of the current docker-compose.
if ! git -C . rev-parse &> /dev/null || [ ! -d "Generated" ]; then
    if [ ! -z $BTCPAY_DOCKER_COMPOSE ]; then
        cd $(dirname $BTCPAY_DOCKER_COMPOSE)
        cd ..
    fi
    if ! git -C . rev-parse || [ ! -d "Generated" ]; then
        echo "You must run this script inside the git repository of btcpayserver-docker"
        return
    fi
fi

function display_help () {
cat <<-END
Usage:
------

Install BTCPay on this server
This script must be run as root

    -i : Run install and start BTCPay Server
    --install-only : Run install only

This script will:

* Install Docker
* Install Docker-Compose
* Setup BTCPay settings
* Make sure it starts at reboot via upstart or systemd
* Add BTCPay utilities in /usr/bin
* Start BTCPay

You can run again this script if you desire to change your configuration.
Except BTC and LTC, other crypto currencies are maintained by their own community. Run at your own risk.

Make sure you own a domain with DNS record pointing to your website and that port 80 is accessible before running this script.
This will be used to properly setup HTTPS via let's encrypt.

Environment variables:
    BTCPAY_HOST: The hostname of your website (eg. btcpay.example.com)
    LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
    NBITCOIN_NETWORK: The type of network to use (eg. mainnet, testnet or regtest. Default: mainnet)
    LIGHTNING_ALIAS: An alias for your lightning network node if used
    BTCPAYGEN_CRYPTO1: First supported crypto currency (eg. btc, ltc, btx, btg, grs, ftc, via, doge, mona, dash, none. Default: btc)
    BTCPAYGEN_CRYPTO2: Second supported crypto currency (Default: empty)
    BTCPAYGEN_CRYPTON: N th supported crypto currency where N is maximum at maximum 9. (Default: none)
    BTCPAYGEN_REVERSEPROXY: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, traefik, none. Default: nginx)
    BTCPAYGEN_LIGHTNING: Lightning network implementation to use (eg. clightning, lnd, none)
    BTCPAYGEN_ADDITIONAL_FRAGMENTS: Semi colon separated list of additional fragments you want to use (eg. opt-save-storage)
    ACME_CA_URI: The API endpoint to ask for HTTPS certificate (default: https://acme-v01.api.letsencrypt.org/directory)
    BTCPAY_HOST_SSHKEYFILE: Optional, SSH private key that BTCPay can use to connect to this VM's SSH server. This key will be copied on BTCPay's data directory
    BTCPAYGEN_DOCKER_IMAGE: Allows you to specify a custom docker image for the generator (Default: btcpayserver/docker-compose-generator)
    BTCPAY_IMAGE: Allows you to specify the btcpayserver docker image to use over the default version. (Default: current stable version of btcpayserver)
    BTCPAY_PROTOCOL: Allows you to specify the external transport protocol of BTCPayServer. (Default: https)
Add-on specific variables:
    LIBREPATRON_HOST: If libre patron is activated with opt-add-librepatron, the hostname of your libre patron website (eg. librepatron.example.com)
    WOOCOMMERCE_HOST: If woocommerce is activated with opt-add-woocommerce, the hostname of your woocommerce website (eg. store.example.com)
    BTCPAYGEN_EXCLUDE_FRAGMENTS:  Semicolon-separated list of fragments you want to forcefully exclude (eg. litecoin-clightning)
    BTCTRANSMUTER_HOST: If btc transmuter is activated with opt-add-btctransmuter, the hostname of your btc transmuter website (eg. store.example.com)
END
}

if [ "$1" != "-i" ] && [ "$1" != "--install-only" ]; then
    display_help
    return
fi

START=true
if [ "$1" == "--install-only" ]; then
    START=false
fi

if [ -z "$BTCPAYGEN_CRYPTO1" ]; then
    if [ -f "/etc/profile.d/btcpay-env.sh" ]; then
        echo "This script must be run as root after running \"sudo su -\""
    else
        echo "BTCPAYGEN_CRYPTO1 should not be empty"
    fi
    return
fi

######### Migration: old pregen environment to new environment ############
if [ ! -z $BTCPAY_DOCKER_COMPOSE ] && [ ! -z $DOWNLOAD_ROOT ] && [ -z $BTCPAYGEN_OLD_PREGEN ]; then 
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/btcpayserver-docker/tree/master#i-deployed-before-btcpay-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    return
fi
#########################################################

[[ $LETSENCRYPT_EMAIL == *@example.com ]] && echo "LETSENCRYPT_EMAIL ends with @example.com, setting to empty email instead" && LETSENCRYPT_EMAIL=""

: "${LETSENCRYPT_EMAIL:=}"
: "${BTCPAYGEN_OLD_PREGEN:=false}"
: "${NBITCOIN_NETWORK:=mainnet}"
: "${BTCPAYGEN_CRYPTO1:=btc}"
: "${BTCPAYGEN_REVERSEPROXY:=nginx}"
: "${BTCPAYGEN_LIGHTNING:=none}"
: "${ACME_CA_URI:=https://acme-v01.api.letsencrypt.org/directory}"
: "${BTCPAY_PROTOCOL:=https}"

OLD_BTCPAY_DOCKER_COMPOSE="$BTCPAY_DOCKER_COMPOSE"
ORIGINAL_DIRECTORY="$(pwd)"
BTCPAY_BASE_DIRECTORY="$(dirname "$(pwd)")"

if [ "$BTCPAYGEN_OLD_PREGEN" == "true" ]; then
    if [[ $(dirname $BTCPAY_DOCKER_COMPOSE) == *Production ]]; then
        BTCPAY_DOCKER_COMPOSE="$(pwd)/Production/docker-compose.generated.yml"
    elif [[ $(dirname $BTCPAY_DOCKER_COMPOSE) == *Production-NoReverseProxy ]]; then
        BTCPAY_DOCKER_COMPOSE="$(pwd)/Production-NoReverseProxy/docker-compose.generated.yml"
    else
        BTCPAY_DOCKER_COMPOSE="$(pwd)/Production/docker-compose.generated.yml"
    fi
else # new deployments must be in Generated
    BTCPAY_DOCKER_COMPOSE="$(pwd)/Generated/docker-compose.generated.yml"
fi

BTCPAY_ENV_FILE="$BTCPAY_BASE_DIRECTORY/.env"

BTCPAY_SSHKEYFILE=""
BTCPAY_SSHTRUSTEDFINGERPRINTS=""
if [[ -f "$BTCPAY_HOST_SSHKEYFILE" ]]; then
    BTCPAY_SSHKEYFILE="/datadir/id_rsa"
    for pubkey in /etc/ssh/ssh_host_*.pub; do
        fingerprint="$(ssh-keygen -l -f $pubkey | awk '{print $2}')"
        BTCPAY_SSHTRUSTEDFINGERPRINTS="$fingerprint;$BTCPAY_SSHTRUSTEDFINGERPRINTS"
    done
fi

if [[ "$BTCPAYGEN_REVERSEPROXY" == "nginx" ]] && [[ "$BTCPAY_HOST" ]]; then
    DOMAIN_NAME="$(echo "$BTCPAY_HOST" | grep -E '^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')"
    if [[ ! "$DOMAIN_NAME" ]]; then
        echo "BTCPAYGEN_REVERSEPROXY is set to nginx, so BTCPAY_HOST must be a domain name which point to this server (with port 80 and 443 open), but the current value of BTCPAY_HOST ('$BTCPAY_HOST') is not a valid domain name."
        return
    fi
    BTCPAY_HOST="$DOMAIN_NAME"
fi

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
. helpers.sh
btcpay_expand_variables

cd "$ORIGINAL_DIRECTORY"

echo "
-------SETUP-----------
Parameters passed:
BTCPAY_PROTOCOL:$BTCPAY_PROTOCOL
BTCPAY_HOST:$BTCPAY_HOST
LIBREPATRON_HOST:$LIBREPATRON_HOST
WOOCOMMERCE_HOST:$WOOCOMMERCE_HOST
BTCTRANSMUTER_HOST:$BTCTRANSMUTER_HOST
BTCPAY_HOST_SSHKEYFILE:$BTCPAY_HOST_SSHKEYFILE
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
BTCPAYGEN_ADDITIONAL_FRAGMENTS:$BTCPAYGEN_ADDITIONAL_FRAGMENTS
BTCPAYGEN_EXCLUDE_FRAGMENTS:$BTCPAYGEN_EXCLUDE_FRAGMENTS
BTCPAY_IMAGE:$BTCPAY_IMAGE
ACME_CA_URI:$ACME_CA_URI
----------------------
Additional exported variables:
BTCPAY_DOCKER_COMPOSE=$BTCPAY_DOCKER_COMPOSE
BTCPAY_BASE_DIRECTORY=$BTCPAY_BASE_DIRECTORY
BTCPAY_ENV_FILE=$BTCPAY_ENV_FILE
BTCPAYGEN_OLD_PREGEN=$BTCPAYGEN_OLD_PREGEN
BTCPAY_SSHKEYFILE=$BTCPAY_SSHKEYFILE
BTCPAY_SSHTRUSTEDFINGERPRINTS:$BTCPAY_SSHTRUSTEDFINGERPRINTS
BTCPAY_CRYPTOS:$BTCPAY_CRYPTOS
BTCPAY_ANNOUNCEABLE_HOST:$BTCPAY_ANNOUNCEABLE_HOST
----------------------
"

if [ -z "$BTCPAYGEN_CRYPTO1" ]; then
    echo "BTCPAYGEN_CRYPTO1 should not be empty"
    return
fi

if [ "$NBITCOIN_NETWORK" != "mainnet" ] && [ "$NBITCOIN_NETWORK" != "testnet" ] && [ "$NBITCOIN_NETWORK" != "regtest" ]; then
    echo "NBITCOIN_NETWORK should be equal to mainnet, testnet or regtest"
fi

# Put the variables in /etc/profile.d when a user log interactively
touch "/etc/profile.d/btcpay-env.sh"
echo "
export COMPOSE_HTTP_TIMEOUT=\"180\"
export BTCPAYGEN_OLD_PREGEN=\"$BTCPAYGEN_OLD_PREGEN\"
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
export BTCPAYGEN_REVERSEPROXY=\"$BTCPAYGEN_REVERSEPROXY\"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS=\"$BTCPAYGEN_ADDITIONAL_FRAGMENTS\"
export BTCPAYGEN_EXCLUDE_FRAGMENTS=\"$BTCPAYGEN_EXCLUDE_FRAGMENTS\"
export BTCPAY_DOCKER_COMPOSE=\"$BTCPAY_DOCKER_COMPOSE\"
export BTCPAY_BASE_DIRECTORY=\"$BTCPAY_BASE_DIRECTORY\"
export BTCPAY_ENV_FILE=\"$BTCPAY_ENV_FILE\"
export BTCPAY_HOST_SSHKEYFILE=\"$BTCPAY_HOST_SSHKEYFILE\"
if cat \"\$BTCPAY_ENV_FILE\" &> /dev/null; then
    export \$(grep -v '^#' \"\$BTCPAY_ENV_FILE\" | xargs)
fi
" > /etc/profile.d/btcpay-env.sh
chmod +x /etc/profile.d/btcpay-env.sh

echo -e "BTCPay Server environment variables successfully saved in /etc/profile.d/btcpay-env.sh\n"

btcpay_update_docker_env
echo -e "BTCPay Server docker-compose parameters saved in $BTCPAY_ENV_FILE\n"

. /etc/profile.d/btcpay-env.sh

if ! [ -x "$(command -v docker)" ] || ! [ -x "$(command -v docker-compose)" ]; then
    if ! [ -x "$(command -v curl)" ]; then
        apt-get update 2>error
        apt-get install -y \
            curl \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            2>error
    fi
    if ! [ -x "$(command -v docker)" ]; then
        if [[ "$(uname -m)" == "x86_64" ]] || [[ "$(uname -m)" == "armv7l" ]]; then
            echo "Trying to install docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            chmod +x get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
        elif [[ "$(uname -m)" == "aarch64" ]]; then
            echo "Trying to install docker for armv7 on a aarch64 board..."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
            RELEASE=$(lsb_release -cs)
            if [[ "$RELEASE" == "bionic" ]]; then
                RELEASE=xenial
            fi
            if [ -x "$(command -v dpkg)" ]; then
                dpkg --add-architecture armhf
            fi
            add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $RELEASE stable"
            apt-get update -y
            # zlib1g:armhf is needed for docker-compose, but we install it here as we changed dpkg here
            apt-get install -y docker-ce:armhf zlib1g:armhf
        fi
    fi
    if ! [ -x "$(command -v docker-compose)" ]; then
        if [[ "$(uname -m)" == "x86_64" ]]; then
            DOCKER_COMPOSE_DOWNLOAD="https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m`"
            echo "Trying to install docker-compose by downloading on $DOCKER_COMPOSE_DOWNLOAD ($(uname -m))"
            curl -L "$DOCKER_COMPOSE_DOWNLOAD" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        else
            echo "Trying to install docker-compose by using the docker-compose-builder ($(uname -m))"
            ! [ -d "dist" ] && mkdir dist
            docker run --rm -ti -v "$(pwd)/dist:/dist" btcpayserver/docker-compose-builder:1.23.2
            mv dist/docker-compose /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            rm -rf "dist"
        fi
    fi
fi

if ! [ -x "$(command -v docker)" ]; then
    echo "Failed to install docker"
    return
fi

if ! [ -x "$(command -v docker-compose)" ]; then
    echo "Failed to install docker-compose"
    return
fi

# Generate the docker compose in BTCPAY_DOCKER_COMPOSE
. ./build.sh

if [ "$BTCPAYGEN_OLD_PREGEN" == "true" ]; then
    cp Generated/docker-compose.generated.yml $BTCPAY_DOCKER_COMPOSE
fi

# Schedule for reboot
if [ -x "$(command -v systemctl)" ]; then # Use systemd
if [ -e "/etc/init/start_containers.conf" ]; then
    echo -e "Uninstalling upstart script /etc/init/start_containers.conf"
    rm "/etc/init/start_containers.conf"
    initctl reload-configuration
fi
echo "Adding btcpayserver.service to systemd"
echo "
[Unit]
Description=BTCPayServer service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" up -d -t \"\$COMPOSE_HTTP_TIMEOUT\"'
ExecStop=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" stop -t \"\$COMPOSE_HTTP_TIMEOUT\"'
ExecReload=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" restart -t \"\$COMPOSE_HTTP_TIMEOUT\"'

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/btcpayserver.service

if ! [ -f "/etc/docker/daemon.json" ]; then
echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" > /etc/docker/daemon.json
echo "Setting limited log files in /etc/docker/daemon.json"
systemctl restart docker
fi

echo -e "BTCPay Server systemd configured in /etc/systemd/system/btcpayserver.service\n"
systemctl daemon-reload
systemctl enable btcpayserver
if $START; then
    echo "BTCPay Server starting... this can take 5 to 10 minutes..."
    systemctl start btcpayserver
    echo "BTCPay Server started"
fi
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
    cd \"\$(dirname \$BTCPAY_ENV_FILE)\"
    docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" up -d
end script" > /etc/init/start_containers.conf
    echo -e "BTCPay Server upstart configured in /etc/init/start_containers.conf\n"
if $START; then
    initctl reload-configuration
    echo "BTCPay Server started"
fi
fi

cd "$(dirname $BTCPAY_ENV_FILE)"

if [ ! -z "$OLD_BTCPAY_DOCKER_COMPOSE" ] && [ "$OLD_BTCPAY_DOCKER_COMPOSE" != "$BTCPAY_DOCKER_COMPOSE" ]; then
    echo "Closing old docker-compose at $OLD_BTCPAY_DOCKER_COMPOSE..."
    docker-compose -f "$OLD_BTCPAY_DOCKER_COMPOSE" down -t "${COMPOSE_HTTP_TIMEOUT:-180}"
fi

$START && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d --remove-orphans -t "${COMPOSE_HTTP_TIMEOUT:-180}"
! $START && docker-compose -f "$BTCPAY_DOCKER_COMPOSE" pull

# Give SSH key to BTCPay
if [[ -f "$BTCPAY_HOST_SSHKEYFILE" ]]; then
    echo "Copying $BTCPAY_SSHKEYFILE to BTCPayServer container"
    docker cp "$BTCPAY_HOST_SSHKEYFILE" $(docker ps --filter "name=_btcpayserver_" -q):$BTCPAY_SSHKEYFILE
fi

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
install_tooling

cd $ORIGINAL_DIRECTORY
