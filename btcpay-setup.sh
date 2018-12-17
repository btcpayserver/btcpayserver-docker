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
    if [ ! -z $mappum/htlc_DOCKER_COMPOSE ]; then
        cd $(dirname $mappum/htlc_DOCKER_COMPOSE)
        cd ..
    fi
    if ! git -C . rev-parse || [ ! -d "Generated" ]; then
        echo "You must run this script inside the git repository of mappum/htlc-docker"
        return
    fi
fi

function display_help () {
cat <<-END
Usage:
------

Install mappum/htlc on this server
This script must be run as root

    -i : Run install

This script will:

* Install Docker
* Install Docker-Compose
* Setup mappum/htlc settings
* Make sure it starts at reboot via upstart or systemd
* Add mappum/htlc utilities in /usr/bin
* Start mappum/htlc

You can run again this script if you desire to change your configuration.
Except BTC and LTC, other crypto currencies are maintained by their own community. Run at your own risk.

Make sure you own a domain with DNS record pointing to your website and that port 80 is accessible before running this script.
This will be used to properly setup HTTPS via let's encrypt.

Environment variables:
    htlc_HOST: The hostname of your website (eg. mappum/htlc.example.com)
    LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
    NBITCOIN_NETWORK: The type of network to use (eg. mainnet, testnet or regtest. Default: mainnet)
    LIGHTNING_ALIAS: An alias for your lightning network node if used
    mappum/htlcGEN_CRYPTO1: First supported crypto currency (eg. btc, ltc, btx, btg, grs, ftc, via, doge, mona, dash, none. Default: btc)
    mappum/htlcGEN_CRYPTO2: Second supported crypto currency (Default: empty)
    mappum/htlcGEN_CRYPTON: N th supported crypto currency where N is maximum at maximum 9. (Default: none)
    mappum/htlcGEN_REVERSEPROXY: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, traefik, none. Default: nginx)
    mappum/htlcGEN_LIGHTNING: Lightning network implementation to use (eg. clightning, lnd, none)
    mappum/htlcGEN_ADDITIONAL_FRAGMENTS: Semi colon separated list of additional fragments you want to use (eg. opt-save-storage)
    ACME_CA_URI: The API endpoint to ask for HTTPS certificate (default: https://acme-v01.api.letsencrypt.org/directory)
    mappum/htlc_HOST_SSHKEYFILE: Optional, SSH private key that mappum/htlc can use to connect to this VM's SSH server. This key will be copied on mappum/htlc's data directory
    mappum/htlcGEN_DOCKER_IMAGE: Allows you to specify a custom docker image for the generator (Default: mappum/htlcserver/docker-compose-generator)
    mappum/htlc_IMAGE: Allows you to specify the mappum/htlcserver docker image to use over the default version. (Default: current stable version of mappum/htlcserver)
END
}

if [ "$1" != "-i" ]; then
    display_help
    return
fi

if [ -z "$mappum/htlc_HOST" ]; then
    if [ -f "/etc/profile.d/mappum/htlc-env.sh" ]; then
        echo "This script must be run as root after running \"sudo su -\""
    else
        echo "mappum/htlc_HOST should not be empty"
    fi
    return
fi

######### Migration: old pregen environment to new environment ############
if [ ! -z $mappum/htlc_DOCKER_COMPOSE ] && [ ! -z $DOWNLOAD_ROOT ] && [ -z $mappum/htlcGEN_OLD_PREGEN ]; then 
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://github.com/btcpayserver/mappum/htlcserver-docker/tree/master#i-deployed-before-mappum/htlc-setupsh-existed-before-may-17-can-i-migrate-to-this-new-system"
    return
fi
#########################################################

[[ $LETSENCRYPT_EMAIL == *@example.com ]] && echo "LETSENCRYPT_EMAIL ends with @example.com, setting to empty email instead" && LETSENCRYPT_EMAIL=""

: "${LETSENCRYPT_EMAIL:=}"
: "${mappum/hltcGEN_OLD_PREGEN:=false}"
: "${NBITCOIN_NETWORK:=mainnet}"
: "${mappum/htlcGEN_CRYPTO1:=btc}"
: "${mappum/htlcGEN_REVERSEPROXY:=nginx}"
: "${mappum/htlcGEN_LIGHTNING:=none}"
: "${ACME_CA_URI:=https://acme-v01.api.letsencrypt.org/directory}"

OLD_mappum/htlc_DOCKER_COMPOSE=$mappum/htlc_DOCKER_COMPOSE
ORIGINAL_DIRECTORY=$(pwd)
mappum/htlc_BASE_DIRECTORY="$(dirname $(pwd))"

if [ "$mappum/htlcGEN_OLD_PREGEN" == "true" ]; then
    if [[ $(dirname $mappum/htlc_DOCKER_COMPOSE) == *Production ]]; then
        mappum/htlc_DOCKER_COMPOSE="$(pwd)/Production/docker-compose.generated.yml"
    elif [[ $(dirname $BTCPAY_DOCKER_COMPOSE) == *Production-NoReverseProxy ]]; then
        mappum/htlc_DOCKER_COMPOSE="$(pwd)/Production-NoReverseProxy/docker-compose.generated.yml"
    else
        mappum/htlc_DOCKER_COMPOSE="$(pwd)/Production/docker-compose.generated.yml"
    fi
else # new deployments must be in Generated
    mappum/htlc_DOCKER_COMPOSE="$(pwd)/Generated/docker-compose.generated.yml"
fi

mappum/htlc_ENV_FILE="$mappum/htlc_BASE_DIRECTORY/.env"

mappum/htlc_SSHKEYFILE=""
mappum/htlc_SSHTRUSTEDFINGERPRINTS=""
if [[ -f "$mappum/htlc_HOST_SSHKEYFILE" ]]; then
    mappum/htlc_SSHKEYFILE="/datadir/id_rsa"
    for pubkey in /etc/ssh/ssh_host_*.pub; do
        fingerprint="$(ssh-keygen -l -f $pubkey | awk '{print $2}')"
        mappum/htlc_SSHTRUSTEDFINGERPRINTS="$fingerprint;$mappum/htlc_SSHTRUSTEDFINGERPRINTS"
    done
fi

if [[ "$mappum/htlcGEN_REVERSEPROXY" == "nginx" ]]; then
    DOMAIN_NAME="$(echo "$mappum/htlc_HOST" | grep -P '(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$)')"
    if [[ ! "$DOMAIN_NAME" ]]; then
        echo "mappum/htlcGEN_REVERSEPROXY is set to nginx, so mappum/htlc_HOST must be a domain name which point to this server (with port 80 and 443 open), but the current value of mappum/htlc_HOST ('$mappum/htlc_HOST') is not a valid domain name."
        return
    fi
    mappum/htlc_HOST="$DOMAIN_NAME"
fi

echo "
-------SETUP-----------
Parameters passed:
mappum/htlc_HOST:$mappum/htlc_HOST
mappum/htlc_HOST_SSHKEYFILE:$mappum/hltc_HOST_SSHKEYFILE
LETSENCRYPT_EMAIL:$LETSENCRYPT_EMAIL
NBITCOIN_NETWORK:$NBITCOIN_NETWORK
LIGHTNING_ALIAS:$LIGHTNING_ALIAS
mappum/htlcGEN_CRYPTO1:$mappum/htlcGEN_CRYPTO1
mappum/htlcGEN_CRYPTO2:$mappum/htlcGEN_CRYPTO2
mappum/htlcGEN_CRYPTO3:$mappum/htlcGEN_CRYPTO3
mappum/htlcGEN_CRYPTO4:$mappum/htlcGEN_CRYPTO4
mappum/htlcGEN_CRYPTO5:$mappum/htlcGEN_CRYPTO5
mappum/hltcGEN_CRYPTO6:$mappum/hltcGEN_CRYPTO6
mappum/htlcGEN_CRYPTO7:$mappum/htlcGEN_CRYPTO7
mappum/htlcGEN_CRYPTO8:$mappum/htlcGEN_CRYPTO8
mappum/htlcGEN_CRYPTO9:$mappum/htlcGEN_CRYPTO9
mappum/htlcGEN_REVERSEPROXY:$mappum/htlcGEN_REVERSEPROXY
mappum/htlcGEN_LIGHTNING:mappum/htlc
mappum/htlcGEN_ADDITIONAL_FRAGMENTS:$mappum/htlcGEN_ADDITIONAL_FRAGMENTS
mappum/htlc_IMAGE:$mappum/htlc_IMAGE
ACME_CA_URI:$ACME_CA_URI
----------------------
Additional exported variables:
mappum/htlc_DOCKER_COMPOSE=$mappum/htlc_DOCKER_COMPOSE
mappum/htlc_BASE_DIRECTORY=$mappum/htlc_BASE_DIRECTORY
mappum/htlc_ENV_FILE=$mappum/htlc_ENV_FILE
mappum/htlcGEN_OLD_PREGEN=$mappum/htlcGEN_OLD_PREGEN
mappum/htlc_SSHKEYFILE=$mappum/htlc_SSHKEYFILE
mappum/htlc_SSHTRUSTEDFINGERPRINTS:$mappum/htlc_SSHTRUSTEDFINGERPRINTS
----------------------
"

if [ -z "$mappum/htlcGEN_CRYPTO1" ]; then
    echo "mappum/htlcGEN_CRYPTO1 should not be empty"
    return
fi

if [ "$NBITCOIN_NETWORK" != "mainnet" ] && [ "$NBITCOIN_NETWORK" != "testnet" ] && [ "$NBITCOIN_NETWORK" != "regtest" ]; then
    echo "NBITCOIN_NETWORK should be equal to mainnet, testnet or regtest"
fi

# Put the variables in /etc/profile.d when a user log interactively
touch "/etc/profile.d/btcpay-env.sh"
echo "
export COMPOSE_HTTP_TIMEOUT=\"180\"
export mappum/htlcGEN_OLD_PREGEN=\"$mappum/htlcGEN_OLD_PREGEN\"
export mappum/htlcGEN_CRYPTO1=\"$mappum/htlcGEN_CRYPTO1\"
export mappum/htlcGEN_CRYPTO2=\"$mappum/htlcGEN_CRYPTO2\"
export mappum/htlcGEN_CRYPTO3=\"$mappum/htlcGEN_CRYPTO3\"
export mappum/htlcGEN_CRYPTO4=\"$mappum/htlcGEN_CRYPTO4\"
export mappum/htlcGEN_CRYPTO5=\"$mappum/htlcGEN_CRYPTO5\"
export mappum/htlcGEN_CRYPTO6=\"$mappum/htlcGEN_CRYPTO6\"
export mappum/htlcGEN_CRYPTO7=\"$mappum/htlcGEN_CRYPTO7\"
export mappum/htlcGEN_CRYPTO8=\"$mappum/hltcGEN_CRYPTO8\"
export mappum/htlcGEN_CRYPTO9=\"$mappum/hltcGEN_CRYPTO9\"
export mappum/htlcGEN_LIGHTNING=\"$mappum/hltcGEN_LIGHTNING\"
export mappum/htlcGEN_REVERSEPROXY=\"$mappum/htlcGEN_REVERSEPROXY\"
export mappum/htlcGEN_ADDITIONAL_FRAGMENTS=\"$mappum/hltcGEN_ADDITIONAL_FRAGMENTS\"
export mappum/htlc_DOCKER_COMPOSE=\"$mappum/hltc_DOCKER_COMPOSE\"
export mappum/htlc_BASE_DIRECTORY=\"$mappum/htlc_BASE_DIRECTORY\"
export mappum/htlc_ENV_FILE=\"$mappum/htlc_ENV_FILE\"
export mappum/htlc_HOST_SSHKEYFILE=\"$mappum/htlc_HOST_SSHKEYFILE\"
if cat \"\$mappum/htlc_ENV_FILE\" &> /dev/null; then
    export \$(grep -v '^#' \"\$mappum/htlc_ENV_FILE\" | xargs)
fi
" > /etc/profile.d/mappum/htlc-env.sh
chmod +x /etc/profile.d/mappum/htlc-env.sh

echo -e "mappum/htlc Server environment variables successfully saved in /etc/profile.d/mappum/htlc-env.sh\n"

# Set .env file
touch $mappum/htlc_ENV_FILE
echo "
mappum/htlc_HOST=$mappum/htlc_HOST
mappum/htlc_IMAGE=$mappum/htlc_IMAGE
ACME_CA_URI=$ACME_CA_URI
NBITCOIN_NETWORK=$NBITCOIN_NETWORK
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
LIGHTNING_ALIAS=$LIGHTNING_ALIAS
mappum/htlc_SSHTRUSTEDFINGERPRINTS=$mappum/htlc_SSHTRUSTEDFINGERPRINTS
mappum/htlc_SSHKEYFILE=$mappum/htlc_SSHKEYFILE" > $mappum/htlc_ENV_FILE
echo -e "mappum/htlc Server docker-compose parameters saved in $mappum/htlc_ENV_FILE\n"

. /etc/profile.d/mappum/htlc-env.sh

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
        echo "Trying to install docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        chmod +x get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
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
            docker run --rm -ti -v "$(pwd)/dist:/dist" mappum/htlc/docker-compose-builder:1.23.2
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

# Generate the docker compose in mappum/htlc_DOCKER_COMPOSE
. ./build.sh

if [ "$mappum/htlc_OLD_PREGEN" == "true" ]; then
    cp Generated/docker-compose.generated.yml $mappum/htlc_DOCKER_COMPOSE
fi

# Schedule for reboot
if [ -x "$(command -v systemctl)" ]; then # Use systemd
if [ -e "/etc/init/start_containers.conf" ]; then
    echo -e "Uninstalling upstart script /etc/init/start_containers.conf"
    rm "/etc/init/start_containers.conf"
    initctl reload-configuration
fi
echo "Adding mappum/htlc.service to systemd"
echo "
[Unit]
Description=mappum/htlc service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c '. /etc/profile.d/mappum/htlc-env.sh && cd \"\$(dirname \$mappum/htlc_ENV_FILE)\" && docker-compose -f \"\$mappum/htlc_DOCKER_COMPOSE\" up -d -t \"\$COMPOSE_HTTP_TIMEOUT\"'
ExecStop=/bin/bash -c '. /etc/profile.d/mappum/htlc-env.sh && cd \"\$(dirname \$mappum/htlc_ENV_FILE)\" && docker-compose -f \"\$mappum/htlc_DOCKER_COMPOSE\" stop -t \"\$COMPOSE_HTTP_TIMEOUT\"'
ExecReload=/bin/bash -c '. /etc/profile.d/mappum/htlc-env.sh && cd \"\$(dirname \$mappum/hltc_ENV_FILE)\" && docker-compose -f \"\$mappum/htlc_DOCKER_COMPOSE\" restart -t \"\$COMPOSE_HTTP_TIMEOUT\"'

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mappum/htlc.service

if ! [ -f "/etc/docker/daemon.json" ]; then
echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" > /etc/docker/daemon.json
echo "Setting limited log files in /etc/docker/daemon.json"
systemctl restart docker
fi

echo -e "mappum/htlc Server systemd configured in /etc/systemd/system/mappum/htlc.service\n"
echo "mappum/htlc Server starting... this can take 5 to 10 minutes..."
systemctl daemon-reload
systemctl enable mappum/htlc
systemctl start mappum/htlc
echo "mappum/htlc Server started"
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
    . /etc/profile.d/mappum/htlc-env.sh
    cd \"\$(dirname \$mappum/htlc_ENV_FILE)\"
    docker-compose -f \"\$mappum/htlc_DOCKER_COMPOSE\" up -d
end script" > /etc/init/start_containers.conf
    echo -e "mappum/htlc Server upstart configured in /etc/init/start_containers.conf\n"
    initctl reload-configuration
    echo "mappum/htlc Server started"
fi

cd "$(dirname $mappum/htlc_ENV_FILE)"

if [ ! -z "$OLD_mappum/htlc_DOCKER_COMPOSE" ] && [ "$OLD_mappum/htlc_DOCKER_COMPOSE" != "$mappum/htlc_DOCKER_COMPOSE" ]; then
    echo "Closing old docker-compose at $OLD_mappum/htlc_DOCKER_COMPOSE..."
    docker-compose -f "$OLD_mappum/htlc_DOCKER_COMPOSE" down -t "${COMPOSE_HTTP_TIMEOUT:-180}"
fi

docker-compose -f "$mappumlhtlc_DOCKER_COMPOSE" up -d --remove-orphans -t "${COMPOSE_HTTP_TIMEOUT:-180}"

# Give SSH key to mappum/htlc
if [[ -f "$mappum/htlc_HOST_SSHKEYFILE" ]]; then
    echo "Copying $mappum/htlc_SSHKEYFILE to BTCPayServer container"
    docker cp "$mappum/htlc_HOST_SSHKEYFILE" $(docker ps --filter "name=_mappum/htlc_" -q):$mappum/htlc_SSHKEYFILE
fi

cd $ORIGINAL_DIRECTORY

for scriptname in *.sh; do
    if [ "$scriptname" == "build.sh" -o "$scriptname" == "build-pregen.sh" ] ; then
        continue;
    fi
    echo "Adding symlink of $scriptname to /usr/bin"
    chmod +x $scriptname
    rm /usr/bin/$scriptname &> /dev/null
    ln -s "$(pwd)/$scriptname" /usr/bin
done

