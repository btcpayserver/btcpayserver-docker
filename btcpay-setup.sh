#!/bin/bash

set +x

if [[ "$0" = "$BASH_SOURCE" ]]; then
    echo "This script must be sourced \". btcpay-setup.sh\"" 
    exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS

    if [[ $EUID -eq 0 ]]; then
        # Running as root is discouraged on Mac OS. Run under the current user instead.
        echo "This script should not be run as root."
        return
    fi

    BASH_PROFILE_SCRIPT="$HOME/btcpay-env.sh"

    # Mac OS doesn't use /etc/profile.d/xxx.sh. Instead we create a new file and load that from ~/.bash_profile
    if [[ ! -f "$HOME/.bash_profile" ]]; then
        touch "$HOME/.bash_profile"
    fi
    if [[ -z $(grep ". \"$BASH_PROFILE_SCRIPT\"" "$HOME/.bash_profile") ]]; then
        # Line does not exist, add it
        echo ". \"$BASH_PROFILE_SCRIPT\"" >> "$HOME/.bash_profile"
    fi

else
    # Root user is not needed for Mac OS
    BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"

    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root after running \"sudo su -\""
        return
    fi
fi

# Verify we are in right folder. If we are not, let's go in the parent folder of the current docker-compose.
if ! git -C . rev-parse &> /dev/null || [ ! -d "Generated" ]; then
    if [[ ! -z $BTCPAY_DOCKER_COMPOSE ]]; then
        cd $(dirname $BTCPAY_DOCKER_COMPOSE)
        cd ..
    fi
    if ! git -C . rev-parse || [[ ! -d "Generated" ]]; then
        echo "You must run this script inside the git repository of btcpayserver-docker"
        return
    fi
fi

function display_help () {
cat <<-END
Usage:
------

Install BTCPay on this server
This script must be run as root, except on Mac OS

    -i : Run install and start BTCPay Server
    --install-only: Run install only
    --docker-unavailable: Same as --install-only, but will also skip install steps requiring docker
    --no-startup-register: Do not register BTCPayServer to start via systemctl or upstart
    --no-systemd-reload: Do not reload systemd configuration

This script will:

* Install Docker
* Install Docker-Compose
* Setup BTCPay settings
* Make sure it starts at reboot via upstart or systemd
* Add BTCPay utilities in /usr/bin
* Start BTCPay

You can run again this script if you desire to change your configuration.
Except BTC and LTC, other crypto currencies are maintained by their own community. Run at your own risk.

Make sure you own a domain with DNS record pointing to your website.
If you want HTTPS setup automatically with Let's Encrypt, leave REVERSEPROXY_HTTP_PORT at it's default value of 80 and make sure this port is accessible from the internet.
Or, if you want to offload SSL because you have an existing web proxy, change REVERSEPROXY_HTTP_PORT to any port you want. You can then forward the traffic. Just don't forget to pass the X-Forwarded-Proto header.

Environment variables:
    BTCPAY_HOST: The hostname of your website (eg. btcpay.example.com)
    REVERSEPROXY_HTTP_PORT: The port the reverse proxy binds to for public HTTP requests. Default: 80
    REVERSEPROXY_HTTPS_PORT: The port the reverse proxy binds to for public HTTPS requests. Default: 443
    REVERSEPROXY_DEFAULT_HOST: Optional, if using a reverse proxy nginx, specify which website should be presented if the server is accessed by its IP.
    LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
    NBITCOIN_NETWORK: The type of network to use (eg. mainnet, testnet or regtest. Default: mainnet)
    LIGHTNING_ALIAS: An alias for your lightning network node if used
    BTCPAYGEN_CRYPTO1: First supported crypto currency (eg. btc, ltc, btx, btg, grs, ftc, via, doge, mona, dash, none. Default: btc)
    BTCPAYGEN_CRYPTO2: Second supported crypto currency (Default: empty)
    BTCPAYGEN_CRYPTON: N th supported crypto currency where N is maximum at maximum 9. (Default: none)
    BTCPAYGEN_REVERSEPROXY: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, traefik, none. Default: nginx)
    BTCPAYGEN_LIGHTNING: Lightning network implementation to use (eg. clightning, lnd, none)
    BTCPAYGEN_ADDITIONAL_FRAGMENTS: Semi colon separated list of additional fragments you want to use (eg. opt-save-storage)
    ACME_CA_URI: The API endpoint to ask for HTTPS certificate (default: production)
    BTCPAY_ENABLE_SSH: Optional, gives BTCPay Server SSH access to the host by allowing it to edit authorized_keys of the host, it can be used for managing the authorized_keys or updating BTCPay Server directly through the website. (Default: false)
    BTCPAYGEN_DOCKER_IMAGE: Allows you to specify a custom docker image for the generator (Default: btcpayserver/docker-compose-generator)
    BTCPAY_IMAGE: Allows you to specify the btcpayserver docker image to use over the default version. (Default: current stable version of btcpayserver)
    BTCPAY_PROTOCOL: Allows you to specify the external transport protocol of BTCPayServer. (Default: https)
    BTCPAY_ADDITIONAL_HOSTS: Allows you to specify additional domains to your BTCPayServer with https support if enabled. (eg. example2.com,example3.com)
Add-on specific variables:
    LIBREPATRON_HOST: If libre patron is activated with opt-add-librepatron, the hostname of your libre patron website (eg. librepatron.example.com)
    ZAMMAD_HOST: If zammad is activated with opt-add-zammad, the hostname of your zammad website (eg. zammad.example.com)
    WOOCOMMERCE_HOST: If woocommerce is activated with opt-add-woocommerce, the hostname of your woocommerce website (eg. store.example.com)
    BTCPAYGEN_EXCLUDE_FRAGMENTS:  Semicolon-separated list of fragments you want to forcefully exclude (eg. litecoin-clightning)
    BTCTRANSMUTER_HOST: If btc transmuter is activated with opt-add-btctransmuter, the hostname of your btc transmuter website (eg. store.example.com)
    TOR_RELAY_NICKNAME: If tor relay is activated with opt-add-tor-relay, the relay nickname
    TOR_RELAY_EMAIL: If tor relay is activated with opt-add-tor-relay, the email for Tor to contact you regarding your relay
END
}
START=""
HAS_DOCKER=true
STARTUP_REGISTER=true
SYSTEMD_RELOAD=true
while (( "$#" )); do
  case "$1" in
    -i)
      START=true
      shift 1
      ;;
    --install-only)
      START=false
      shift 1
      ;;
    --docker-unavailable)
      START=false
      HAS_DOCKER=false
      shift 1
      ;;
    --no-startup-register)
      STARTUP_REGISTER=false
      shift 1
      ;;
    --no-systemd-reload)
      SYSTEMD_RELOAD=false
      shift 1
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      display_help
      return
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# If start does not have a value, stop here
if ! [[ "$START" ]]; then
    display_help
    return
fi

if [[ -z "$BTCPAYGEN_CRYPTO1" ]]; then
    if [[ "$OSTYPE" != "darwin"* ]]; then
        # Not Mac OS - Mac OS uses it's own env file
        if [[ -f "$BASH_PROFILE_SCRIPT" ]]; then
            echo "This script must be run as root after running \"sudo su -\""
        else
            echo "BTCPAYGEN_CRYPTO1 should not be empty"
        fi
        return
    fi
fi

if [ ! -z "$BTCPAY_ADDITIONAL_HOSTS" ] && [[ "$BTCPAY_ADDITIONAL_HOSTS" == *[';']* ]]; then 
    echo "$BTCPAY_ADDITIONAL_HOSTS should be separated by a , not ;"
    return;
fi

if [ ! -z "$BTCPAY_ADDITIONAL_HOSTS" ] && [[ "$BTCPAY_ADDITIONAL_HOSTS" == .onion* ]]; then
    echo "$BTCPAY_ADDITIONAL_HOSTS should not contain onion hosts, additional hosts is only for getting https certificates, those are not available to tor addresses"
    return;
fi
######### Migration: old pregen environment to new environment ############
if [[ ! -z $BTCPAY_DOCKER_COMPOSE ]] && [[ ! -z $DOWNLOAD_ROOT ]] && [[ -z $BTCPAYGEN_OLD_PREGEN ]]; then
    echo "Your deployment is too old, you need to migrate by following instructions on this link https://docs.btcpayserver.org/Docker/#i-deployed-before-btcpay-setup-sh-existed-before-may-17-2018-can-i-migrate-to-this-new-system"
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
: "${REVERSEPROXY_DEFAULT_HOST:=none}"
: "${ACME_CA_URI:=production}"
: "${BTCPAY_PROTOCOL:=https}"
: "${BTCPAY_ADDITIONAL_HOSTS:=}"
: "${REVERSEPROXY_HTTP_PORT:=80}"
: "${REVERSEPROXY_HTTPS_PORT:=443}"
: "${BTCPAY_ENABLE_SSH:=false}"
: "${PIHOLE_SERVERIP:=}"

OLD_BTCPAY_DOCKER_COMPOSE="$BTCPAY_DOCKER_COMPOSE"
ORIGINAL_DIRECTORY="$(pwd)"
BTCPAY_BASE_DIRECTORY="$(dirname "$(pwd)")"

if [[ "$BTCPAYGEN_OLD_PREGEN" == "true" ]]; then
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
use_ssh=false

if $BTCPAY_ENABLE_SSH && ! [[ "$BTCPAY_HOST_SSHAUTHORIZEDKEYS" ]]; then
    BTCPAY_HOST_SSHAUTHORIZEDKEYS=~/.ssh/authorized_keys
    BTCPAY_HOST_SSHKEYFILE=""
fi

if [[ -f "$BTCPAY_HOST_SSHKEYFILE" ]]; then
    echo -e "\033[33mWARNING: BTCPAY_HOST_SSHKEYFILE is now deprecated, use instead BTCPAY_ENABLE_SSH=true and run again '. btcpay-setup.sh -i'\033[0m"
    BTCPAY_SSHKEYFILE="/datadir/id_rsa"
    use_ssh=true
fi

if $BTCPAY_ENABLE_SSH && [[ "$BTCPAY_HOST_SSHAUTHORIZEDKEYS" ]]; then
    if ! [[ -f "$BTCPAY_HOST_SSHAUTHORIZEDKEYS" ]]; then
        mkdir -p "$(dirname $BTCPAY_HOST_SSHAUTHORIZEDKEYS)"
        touch $BTCPAY_HOST_SSHAUTHORIZEDKEYS
    fi
    BTCPAY_SSHAUTHORIZEDKEYS="/datadir/host_authorized_keys"
    BTCPAY_SSHKEYFILE="/datadir/host_id_rsa"
    use_ssh=true
fi

# Do not set BTCPAY_SSHTRUSTEDFINGERPRINTS in the setup, since we connect from inside the docker container to the host, this is fine
BTCPAY_SSHTRUSTEDFINGERPRINTS=""

if [[ "$BTCPAYGEN_REVERSEPROXY" == "nginx" ]] && [[ "$BTCPAY_HOST" ]]; then
    DOMAIN_NAME="$(echo "$BTCPAY_HOST" | grep -E '^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')"
    if [[ ! "$DOMAIN_NAME" ]]; then
        echo "BTCPAYGEN_REVERSEPROXY is set to nginx, so BTCPAY_HOST must be a domain name which point to this server, but the current value of BTCPAY_HOST ('$BTCPAY_HOST') is not a valid domain name."
        return
    fi
    BTCPAY_HOST="$DOMAIN_NAME"
fi

# Since opt-txindex requires unpruned node, throw an error if both
# opt-txindex and opt-save-storage-* are enabled together
if [[ "${BTCPAYGEN_ADDITIONAL_FRAGMENTS}" == *opt-txindex* ]] && \
   [[ "${BTCPAYGEN_ADDITIONAL_FRAGMENTS}" == *opt-save-storage* ]];then
        echo "Error: BTCPAYGEN_ADDITIONAL_FRAGMENTS contains both opt-txindex and opt-save-storage*"
        echo "opt-txindex requires an unpruned node, so you cannot use opt-save-storage with it"
        return
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
BTCPAY_ADDITIONAL_HOSTS:$BTCPAY_ADDITIONAL_HOSTS
REVERSEPROXY_HTTP_PORT:$REVERSEPROXY_HTTP_PORT
REVERSEPROXY_HTTPS_PORT:$REVERSEPROXY_HTTPS_PORT
REVERSEPROXY_DEFAULT_HOST:$REVERSEPROXY_DEFAULT_HOST
LIBREPATRON_HOST:$LIBREPATRON_HOST
ZAMMAD_HOST:$ZAMMAD_HOST
WOOCOMMERCE_HOST:$WOOCOMMERCE_HOST
BTCTRANSMUTER_HOST:$BTCTRANSMUTER_HOST
BTCPAY_ENABLE_SSH:$BTCPAY_ENABLE_SSH
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
TOR_RELAY_NICKNAME: $TOR_RELAY_NICKNAME
TOR_RELAY_EMAIL: $TOR_RELAY_EMAIL
PIHOLE_SERVERIP: $PIHOLE_SERVERIP
----------------------
Additional exported variables:
BTCPAY_DOCKER_COMPOSE=$BTCPAY_DOCKER_COMPOSE
BTCPAY_BASE_DIRECTORY=$BTCPAY_BASE_DIRECTORY
BTCPAY_ENV_FILE=$BTCPAY_ENV_FILE
BTCPAYGEN_OLD_PREGEN=$BTCPAYGEN_OLD_PREGEN
BTCPAY_SSHKEYFILE=$BTCPAY_SSHKEYFILE
BTCPAY_SSHAUTHORIZEDKEYS=$BTCPAY_SSHAUTHORIZEDKEYS
BTCPAY_HOST_SSHAUTHORIZEDKEYS:$BTCPAY_HOST_SSHAUTHORIZEDKEYS
BTCPAY_SSHTRUSTEDFINGERPRINTS:$BTCPAY_SSHTRUSTEDFINGERPRINTS
BTCPAY_CRYPTOS:$BTCPAY_CRYPTOS
BTCPAY_ANNOUNCEABLE_HOST:$BTCPAY_ANNOUNCEABLE_HOST
----------------------
"

if [[ -z "$BTCPAYGEN_CRYPTO1" ]]; then
    echo "BTCPAYGEN_CRYPTO1 should not be empty"
    return
fi

if [[ "$NBITCOIN_NETWORK" != "mainnet" ]] && [[ "$NBITCOIN_NETWORK" != "testnet" ]] && [[ "$NBITCOIN_NETWORK" != "regtest" ]]; then
    echo "NBITCOIN_NETWORK should be equal to mainnet, testnet or regtest"
fi



# Init the variables when a user log interactively
touch "$BASH_PROFILE_SCRIPT"
echo "
#!/bin/bash
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
export BTCPAY_ENABLE_SSH=$BTCPAY_ENABLE_SSH
export PIHOLE_SERVERIP=\"$PIHOLE_SERVERIP\"
if cat \"\$BTCPAY_ENV_FILE\" &> /dev/null; then
  while IFS= read -r line; do
    ! [[ \"\$line\" == \"#\"* ]] && [[ \"\$line\" == *\"=\"* ]] && export \"\$line\"
  done < \"\$BTCPAY_ENV_FILE\"
fi
" > ${BASH_PROFILE_SCRIPT}

chmod +x ${BASH_PROFILE_SCRIPT}

echo -e "BTCPay Server environment variables successfully saved in $BASH_PROFILE_SCRIPT\n"


btcpay_update_docker_env

echo -e "BTCPay Server docker-compose parameters saved in $BTCPAY_ENV_FILE\n"

. "$BASH_PROFILE_SCRIPT"

if ! [[ -x "$(command -v docker)" ]] || ! [[ -x "$(command -v docker-compose)" ]]; then
    if ! [[ -x "$(command -v curl)" ]]; then
        apt-get update 2>error
        apt-get install -y \
            curl \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            2>error
    fi
    if ! [[ -x "$(command -v docker)" ]]; then
        if [[ "$(uname -m)" == "x86_64" ]] || [[ "$(uname -m)" == "armv7l" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # Mac OS	
                if ! [[ -x "$(command -v brew)" ]]; then
                    # Brew is not installed, install it now
                    echo "Homebrew, the package manager for Mac OS, is not installed. Installing it now..."
                    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
                fi
                if [[ -x "$(command -v brew)" ]]; then
                    echo "Homebrew is installed, but Docker isn't. Installing it now using brew..."
                    # Brew is installed, install docker now
                    # This sequence is a bit strange, but it's what what needed to get it working on a fresh Mac OS X Mojave install
                    brew cask install docker
                    brew install docker
                    brew link docker
                fi
            else
                # Not Mac OS
                echo "Trying to install docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                chmod +x get-docker.sh
                sh get-docker.sh
                rm get-docker.sh
            fi
        else
            echo "Unsupported architecture $(uname -m)"
            return
        fi
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        if ! [[ "$OSTYPE" == "darwin"* ]] && $HAS_DOCKER; then
            echo "Trying to install docker-compose by using the btcpayserver/docker-compose ($(uname -m))"
            ! [[ -d "dist" ]] && mkdir dist
            docker run --rm -v "$(pwd)/dist:/dist" btcpayserver/docker-compose:1.28.6
            mv dist/docker-compose /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            rm -rf "dist"
        fi
    fi
fi

if $HAS_DOCKER; then
    if ! [[ -x "$(command -v docker)" ]]; then
        echo "Failed to install 'docker'. Please install docker manually, then retry."
        return
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        echo "Failed to install 'docker-compose'. Please install docker-compose manually, then retry."
        return
    fi
fi

# Generate the docker compose in BTCPAY_DOCKER_COMPOSE
if $HAS_DOCKER; then
    if ! ./build.sh; then
        echo "Failed to generate the docker-compose"
        return
    fi
fi

if [[ "$BTCPAYGEN_OLD_PREGEN" == "true" ]]; then
    cp Generated/docker-compose.generated.yml $BTCPAY_DOCKER_COMPOSE
fi

# Schedule for reboot
if $STARTUP_REGISTER && [[ -x "$(command -v systemctl)" ]]; then
    # Use systemd
    if [[ -e "/etc/init/start_containers.conf" ]]; then
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

ExecStart=/bin/bash -c  '. \"$BASH_PROFILE_SCRIPT\" && cd \"\$BTCPAY_BASE_DIRECTORY/btcpayserver-docker\" && . helpers.sh && btcpay_up'
ExecStop=/bin/bash -c   '. \"$BASH_PROFILE_SCRIPT\" && cd \"\$BTCPAY_BASE_DIRECTORY/btcpayserver-docker\" && . helpers.sh && btcpay_down'
ExecReload=/bin/bash -c '. \"$BASH_PROFILE_SCRIPT\" && cd \"\$BTCPAY_BASE_DIRECTORY/btcpayserver-docker\" && . helpers.sh && btcpay_restart'

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/btcpayserver.service

    if ! [[ -f "/etc/docker/daemon.json" ]] && [ -w "/etc/docker" ]; then
        echo "{
\"log-driver\": \"json-file\",
\"log-opts\": {\"max-size\": \"5m\", \"max-file\": \"3\"}
}" > /etc/docker/daemon.json
        echo "Setting limited log files in /etc/docker/daemon.json"
        $SYSTEMD_RELOAD && $START && systemctl restart docker
    fi

    echo -e "BTCPay Server systemd configured in /etc/systemd/system/btcpayserver.service\n"
    if $SYSTEMD_RELOAD; then
        systemctl daemon-reload
        systemctl enable btcpayserver
        if $START; then
            echo "BTCPay Server starting... this can take 5 to 10 minutes..."
            systemctl start btcpayserver
            echo "BTCPay Server started"
        fi
    else
        systemctl --no-reload enable btcpayserver
    fi
elif $STARTUP_REGISTER && [[ -x "$(command -v initctl)" ]]; then
    # Use upstart
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
    . \"$BASH_PROFILE_SCRIPT\"
    cd \"\$BTCPAY_BASE_DIRECTORY/btcpayserver-docker\"
    . helpers.sh
    btcpay_up
end script" > /etc/init/start_containers.conf
    echo -e "BTCPay Server upstart configured in /etc/init/start_containers.conf\n"

    if $START; then
        initctl reload-configuration
    fi
fi


cd "$(dirname $BTCPAY_ENV_FILE)"

if $HAS_DOCKER && [[ ! -z "$OLD_BTCPAY_DOCKER_COMPOSE" ]] && [[ "$OLD_BTCPAY_DOCKER_COMPOSE" != "$BTCPAY_DOCKER_COMPOSE" ]]; then
    echo "Closing old docker-compose at $OLD_BTCPAY_DOCKER_COMPOSE..."
    docker-compose -f "$OLD_BTCPAY_DOCKER_COMPOSE" down -t "${COMPOSE_HTTP_TIMEOUT:-180}"
fi

if $START; then
    btcpay_up
elif $HAS_DOCKER; then
    btcpay_pull
fi

# Give SSH key to BTCPay
if $START && [[ -f "$BTCPAY_HOST_SSHKEYFILE" ]]; then
    echo -e "\033[33mWARNING: BTCPAY_HOST_SSHKEYFILE is now deprecated, use instead BTCPAY_ENABLE_SSH=true and run again '. btcpay-setup.sh -i'\033[0m"
    echo "Copying $BTCPAY_SSHKEYFILE to BTCPayServer container"
    docker cp "$BTCPAY_HOST_SSHKEYFILE" $(docker ps --filter "name=_btcpayserver_" -q):$BTCPAY_SSHKEYFILE
fi

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
install_tooling

cd $ORIGINAL_DIRECTORY
