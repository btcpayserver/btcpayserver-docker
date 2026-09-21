#!/bin/bash

set +x

if [[ "$0" = "$BASH_SOURCE" ]]; then
    echo "This script must be sourced \". btcpay-setup.sh\"" 
    exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "This script only supports Linux hosts."
    return 1
fi

BASH_PROFILE_SCRIPT="/etc/profile.d/btcpay-env.sh"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root after running \"sudo su -\""
    return 1
fi

# Verify we are in right folder. If we are not, let's go in the parent folder of the current docker-compose.
if ! git rev-parse --git-dir &> /dev/null || [ ! -d "Generated" ]; then
    if [[ ! -z $BTCPAY_DOCKER_COMPOSE ]]; then
        if ! cd "$(dirname "$BTCPAY_DOCKER_COMPOSE")" || ! cd ..; then
            echo "Failed to locate the BTCPay Server Docker repository"
            return 1
        fi
    fi
    if ! git rev-parse || [[ ! -d "Generated" ]]; then
        echo "You must run this script inside the git repository of btcpayserver-docker"
        return 1
    fi
fi

function display_help () {
cat <<-END
Usage:
------

Install BTCPay on this server
This script must be run as root on a Linux host

    -i : Run install and start BTCPay Server
    --install-only: Run install only
    --docker-unavailable: Allow install-only setup to continue without Docker; automatic Docker installation may still be attempted
    --no-startup-register: Do not register BTCPayServer to start via systemctl or upstart
    --no-systemd-reload: Do not reload systemd configuration

This script will:

* Install Docker
* Install Docker-Compose
* Setup BTCPay settings
* Make sure it starts at reboot via upstart or systemd
* Add BTCPay utilities in /usr/local/bin
* Start BTCPay

You can run again this script if you desire to change your configuration.
Except BTC and LTC, other crypto currencies are maintained by their own community. Run at your own risk.

BTCPAY_HOST may be empty for local or manually proxied deployments.
If you want HTTPS setup automatically with Let's Encrypt, set BTCPAY_HOST to a domain whose DNS records point to this server, leave REVERSEPROXY_HTTP_PORT at its default value of 80, and make sure this port is accessible from the internet.
Or, if you want to offload SSL because you have an existing web proxy, change REVERSEPROXY_HTTP_PORT to any port you want and set TRUST_DOWNSTREAM_PROXY=true. You can then forward the traffic and its X-Forwarded-* headers.

Environment variables:
    BTCPAY_HOST: Optional primary hostname of your website (eg. btcpay.example.com). Required for automatic public HTTPS.
    BTCPAY_LIGHTNING_HOST: The hostname announced for your node on the lightning network (by default, the BTCPAY_HOST will be used)
    REVERSEPROXY_HTTP_PORT: The port the reverse proxy binds to for public HTTP requests. Default: 80
    REVERSEPROXY_HTTPS_PORT: The port the reverse proxy binds to for public HTTPS requests. Default: 443
    REVERSEPROXY_DEFAULT_HOST: Optional, if using a reverse proxy nginx, specify which website should be presented if the server is accessed by its IP.
    TRUST_DOWNSTREAM_PROXY: Trust X-Forwarded-* headers from an external reverse proxy. Only enable when direct access to the Nginx port is blocked. Default: false
    LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com)
    NBITCOIN_NETWORK: The type of network to use (eg. mainnet, testnet or regtest. Default: mainnet)
    LIGHTNING_ALIAS: An alias for your lightning network node if used
    BTCPAYGEN_CRYPTO1: First supported crypto currency (btc, ltc, grs, ftc, doge, mona, dash, xmr, bdx, lbtc, zec, dcr. Default: btc)
    BTCPAYGEN_CRYPTO2: Second supported crypto currency (Default: empty)
    BTCPAYGEN_CRYPTON: Nth supported crypto currency, where N is at most 9. (Default: empty)
    BTCPAYGEN_REVERSEPROXY: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, none. Default: nginx)
    BTCPAYGEN_LIGHTNING: Lightning network implementation to use (eg. clightning, lnd, phoenixd, none. Default: none)
    BTCPAYGEN_ADDITIONAL_FRAGMENTS: Semi colon separated list of additional fragments you want to use (eg. opt-save-storage)
    ACME_CA_URI: The API endpoint to ask for HTTPS certificate (default: production)
    BTCPAYGEN_DOCKER_IMAGE: Allows you to specify a custom docker image for the generator (Default: btcpayserver/docker-compose-generator)
    BTCPAY_IMAGE: Allows you to specify the btcpayserver docker image to use over the default version. (Default: current stable version of btcpayserver, eg. btcpayserver/btcpayserver:version)
    BTCPAY_UPDATE_CLEAN: Remove all unused Docker images after an update except generator-labeled images. (Default: true)
    BTCPAY_PROTOCOL: Allows you to specify the external transport protocol of BTCPayServer. (Default: https)
    BTCPAY_ADDITIONAL_HOSTS: Allows you to specify additional domains to your BTCPayServer with https support if enabled. (eg. example2.com,example3.com)
Add-on specific variables:
    ZAMMAD_HOST: If zammad is activated with opt-add-zammad, the hostname of your zammad website (eg. zammad.example.com)
    WOOCOMMERCE_HOST: If woocommerce is activated with opt-add-woocommerce, the hostname of your woocommerce website (eg. store.example.com)
    BTCPAYGEN_EXCLUDE_FRAGMENTS:  Semicolon-separated list of fragments you want to forcefully exclude (eg. bitcoin-clightning)
    TOR_RELAY_NICKNAME: If tor relay is activated with opt-add-tor-relay, the relay nickname
    TOR_RELAY_EMAIL: If tor relay is activated with opt-add-tor-relay, the email for Tor to contact you regarding your relay
    CLOUDFLARE_TUNNEL_TOKEN: Used to expose your instance to clearnet with a Cloudflare Argo Tunnel
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
      return 1
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
    if [[ -f "$BASH_PROFILE_SCRIPT" ]]; then
        echo "This script must be run as root after running \"sudo su -\""
    else
        echo "BTCPAYGEN_CRYPTO1 should not be empty"
    fi
    return 1
fi

if [ ! -z "$BTCPAY_ADDITIONAL_HOSTS" ] && [[ "$BTCPAY_ADDITIONAL_HOSTS" == *[';']* ]]; then 
    echo "$BTCPAY_ADDITIONAL_HOSTS should be separated by a , not ;"
    return 1
fi

if [ ! -z "$BTCPAY_ADDITIONAL_HOSTS" ] && [[ "$BTCPAY_ADDITIONAL_HOSTS" == .onion* ]]; then
    echo "$BTCPAY_ADDITIONAL_HOSTS should not contain onion hosts, additional hosts is only for getting https certificates, those are not available to tor addresses"
    return 1
fi

[[ $LETSENCRYPT_EMAIL == *@example.com ]] && echo "LETSENCRYPT_EMAIL ends with @example.com, setting to empty email instead" && LETSENCRYPT_EMAIL=""

: "${LETSENCRYPT_EMAIL:=}"
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
: "${TRUST_DOWNSTREAM_PROXY:=false}"
: "${PIHOLE_SERVERIP:=}"
: "${CLOUDFLARE_TUNNEL_TOKEN:=}"
: "${BTCPAY_UPDATE_CLEAN:=true}"

OLD_BTCPAY_DOCKER_COMPOSE="$BTCPAY_DOCKER_COMPOSE"
ORIGINAL_DIRECTORY="$(pwd)"
BTCPAY_BASE_DIRECTORY="$(dirname "$(pwd)")"
BTCPAY_DOCKER_COMPOSE="$(pwd)/Generated/docker-compose.generated.yml"

BTCPAY_ENV_FILE="$BTCPAY_BASE_DIRECTORY/.env"

if [[ "$BTCPAYGEN_REVERSEPROXY" == "nginx" ]] && [[ "$BTCPAY_HOST" ]]; then
    DOMAIN_NAME="$(echo "$BTCPAY_HOST" | grep -E '^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')"
    if [[ ! "$DOMAIN_NAME" ]]; then
        echo "BTCPAYGEN_REVERSEPROXY is set to nginx, so BTCPAY_HOST must be a domain name which point to this server, but the current value of BTCPAY_HOST ('$BTCPAY_HOST') is not a valid domain name."
        return 1
    fi
    BTCPAY_HOST="$DOMAIN_NAME"
fi

# Since opt-txindex requires unpruned node, throw an error if both
# opt-txindex and opt-save-storage-* are enabled together
if [[ "${BTCPAYGEN_ADDITIONAL_FRAGMENTS}" == *opt-txindex* ]] && \
   [[ "${BTCPAYGEN_ADDITIONAL_FRAGMENTS}" == *opt-save-storage* ]];then
        echo "Error: BTCPAYGEN_ADDITIONAL_FRAGMENTS contains both opt-txindex and opt-save-storage*"
        echo "opt-txindex requires an unpruned node, so you cannot use opt-save-storage with it"
        return 1
fi

if ! cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"; then
    echo "Failed to open the BTCPay Server Docker repository"
    return 1
fi
if ! . helpers.sh; then
    echo "Failed to load BTCPay Server helper functions"
    return 1
fi
if ! btcpay_setup_ssh; then
    echo "Failed to configure BTCPay Server SSH integration"
    return 1
fi
btcpay_expand_variables

if ! cd "$ORIGINAL_DIRECTORY"; then
    echo "Failed to return to the original directory"
    return 1
fi

echo "
-------SETUP-----------
Parameters passed:"
for variable in "${BTCPAY_ENV_VARIABLES[@]}"; do
    case "$variable" in
        CLOUDFLARE_TUNNEL_TOKEN)
            continue
            ;;
    esac
    printf '%s:%s\n' "$variable" "${!variable-}"
done
cat <<END
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
PIHOLE_SERVERIP: $PIHOLE_SERVERIP
----------------------
Additional exported variables:
BTCPAY_DOCKER_COMPOSE=$BTCPAY_DOCKER_COMPOSE
BTCPAY_BASE_DIRECTORY=$BTCPAY_BASE_DIRECTORY
BTCPAY_ENV_FILE=$BTCPAY_ENV_FILE
----------------------
END

if [[ -z "$BTCPAYGEN_CRYPTO1" ]]; then
    echo "BTCPAYGEN_CRYPTO1 should not be empty"
    return 1
fi

if [[ "$NBITCOIN_NETWORK" != "mainnet" ]] && [[ "$NBITCOIN_NETWORK" != "testnet" ]] && [[ "$NBITCOIN_NETWORK" != "regtest" ]]; then
    echo "NBITCOIN_NETWORK should be equal to mainnet, testnet or regtest"
    return 1
fi



# Init the variables when a user logs in interactively.
profile_tmp="$(mktemp "${BASH_PROFILE_SCRIPT}.tmp.XXXXXX")" || return 1
if ! {
    printf '#!/bin/bash\n'
    printf 'export COMPOSE_HTTP_TIMEOUT=%q\n' "180"
    for variable in \
        BTCPAYGEN_CRYPTO1 BTCPAYGEN_CRYPTO2 BTCPAYGEN_CRYPTO3 \
        BTCPAYGEN_CRYPTO4 BTCPAYGEN_CRYPTO5 BTCPAYGEN_CRYPTO6 \
        BTCPAYGEN_CRYPTO7 BTCPAYGEN_CRYPTO8 BTCPAYGEN_CRYPTO9 \
        BTCPAYGEN_LIGHTNING BTCPAYGEN_REVERSEPROXY \
        BTCPAYGEN_ADDITIONAL_FRAGMENTS BTCPAYGEN_EXCLUDE_FRAGMENTS \
        BTCPAY_DOCKER_COMPOSE BTCPAY_BASE_DIRECTORY BTCPAY_ENV_FILE \
        PIHOLE_SERVERIP; do
        printf 'export %s=%q\n' "$variable" "${!variable-}"
    done
    cat <<'EOF'
if cat "$BTCPAY_ENV_FILE" &> /dev/null; then
  while IFS= read -r line; do
    ! [[ "$line" == "#"* ]] && [[ "$line" == *"="* ]] && export "$line"
  done < "$BTCPAY_ENV_FILE"
fi
EOF
} > "$profile_tmp"; then
    rm -f -- "$profile_tmp"
    echo "Failed to write BTCPay Server environment profile"
    return 1
fi

# Contrary to the other environment variables, an empty BTCPAY_LETSENCRYPT_HOSTS and an unset one
# behave differently (empty disables Let's Encrypt, unset requests certificates for all hosts),
# so only save it when it is explicitly set.
if [[ "${BTCPAY_LETSENCRYPT_HOSTS+x}" ]]; then
    if ! printf 'export BTCPAY_LETSENCRYPT_HOSTS=%q\n' "$BTCPAY_LETSENCRYPT_HOSTS" >> "$profile_tmp"; then
        rm -f -- "$profile_tmp"
        echo "Failed to save BTCPAY_LETSENCRYPT_HOSTS"
        return 1
    fi
fi

if ! chmod 755 "$profile_tmp" || ! mv -f -- "$profile_tmp" "$BASH_PROFILE_SCRIPT"; then
    rm -f -- "$profile_tmp"
    echo "Failed to install BTCPay Server environment profile"
    return 1
fi

echo -e "BTCPay Server environment variables successfully saved in $BASH_PROFILE_SCRIPT\n"


if ! btcpay_update_docker_env; then
    echo "Failed to save BTCPay Server docker-compose parameters"
    return 1
fi

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
            jq \
            2>error
    fi
    if ! [[ -x "$(command -v docker)" ]]; then
        if [[ "$(uname -m)" == "x86_64" ]] || [[ "$(uname -m)" == "armv7l" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
            echo "Trying to install docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            chmod +x get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
        else
            echo "Unsupported architecture $(uname -m)"
            return 1
        fi
    fi

    if ! docker_update; then
        echo "Failed to update Docker or Docker Compose"
        return 1
    fi
fi

if $HAS_DOCKER; then
    if ! [[ -x "$(command -v docker)" ]]; then
        echo "Failed to install 'docker'. Please install docker manually, then retry."
        return 1
    fi

    if ! [[ -x "$(command -v docker-compose)" ]]; then
        echo "Failed to install 'docker-compose'. Please install docker-compose manually, then retry."
        return 1
    fi
fi

# Generate the docker compose in BTCPAY_DOCKER_COMPOSE
if $HAS_DOCKER; then
    if ! ./build.sh --setup-ssh --sync-routes; then
        echo "Failed to generate the docker-compose"
        return 1
    fi
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
        if $SYSTEMD_RELOAD && $START && ! systemctl restart docker; then
            echo "Failed to restart Docker"
            return 1
        fi
    fi

    echo -e "BTCPay Server systemd configured in /etc/systemd/system/btcpayserver.service\n"
    if $SYSTEMD_RELOAD; then
        if ! systemctl daemon-reload || ! systemctl enable btcpayserver; then
            echo "Failed to register BTCPay Server with systemd"
            return 1
        fi
        if $START; then
            echo "BTCPay Server starting... this can take 5 to 10 minutes..."
            if ! systemctl start btcpayserver; then
                echo "Failed to start BTCPay Server through systemd"
                return 1
            fi
            echo "BTCPay Server started"
        fi
    else
        if ! systemctl --no-reload enable btcpayserver; then
            echo "Failed to enable BTCPay Server through systemd"
            return 1
        fi
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
        if ! initctl reload-configuration; then
            echo "Failed to reload the Upstart configuration"
            return 1
        fi
    fi
fi


if ! cd "$(dirname "$BTCPAY_ENV_FILE")"; then
    echo "Failed to open the BTCPay Server base directory"
    return 1
fi

if $HAS_DOCKER && [[ ! -z "$OLD_BTCPAY_DOCKER_COMPOSE" ]] && [[ "$OLD_BTCPAY_DOCKER_COMPOSE" != "$BTCPAY_DOCKER_COMPOSE" ]]; then
    echo "Closing old docker-compose at $OLD_BTCPAY_DOCKER_COMPOSE..."
    if ! docker-compose -f "$OLD_BTCPAY_DOCKER_COMPOSE" down -t "${COMPOSE_HTTP_TIMEOUT:-180}"; then
        echo "Failed to stop the old BTCPay Server stack"
        return 1
    fi
fi

if $START; then
    if ! btcpay_up; then
        echo "Failed to start BTCPay Server"
        return 1
    fi
elif $HAS_DOCKER; then
    if ! btcpay_pull; then
        echo "Failed to pull BTCPay Server images"
        return 1
    fi
fi

if ! cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"; then
    echo "Failed to open the BTCPay Server Docker repository"
    return 1
fi
if ! install_tooling; then
    echo "Failed to install BTCPay Server command-line tools"
    return 1
fi

if ! cd "$ORIGINAL_DIRECTORY"; then
    echo "Failed to return to the original directory"
    return 1
fi
