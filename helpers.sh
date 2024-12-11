install_tooling() {
    scripts=( \
                "btcpayserver_bitcoind" "bitcoin-cli.sh" "Command line for your Bitcoin instance" \
                "btcpayserver_clightning_bitcoin" "bitcoin-lightning-cli.sh" "Command line for your Bitcoin C-Lightning instance" \
                "btcpayserver_lnd_bitcoin" "bitcoin-lncli.sh" "Command line for your Bitcoin LND instance" \
                "btcpayserver_bgoldd" "bgold-cli.sh" "Command line for your BGold instance" \
                "btcpayserver_bitcored" "bitcore-cli.sh" "Command line for your Bitcore instance" \
                "btcpayserver_bitcoinplusd" "bplus-cli.sh" "Command line for your BPlus instance" \
                "btcpayserver_dashd" "dash-cli.sh" "Command line for your Dash instance" \
                "btcpayserver_dogecoind" "dogecoin-cli.sh" "Command line for your Dogecoin instance" \
                "btcpayserver_feathercoind" "feathercoin-cli.sh" "Command line for your Feathercoin instance" \
                "btcpayserver_groestlcoind" "groestlcoin-cli.sh" "Command line for your Groestlcoin instance" \
                "btcpayserver_clightning_groestlcoin" "groestlcoin-lightning-cli.sh" "Command line for your Groestlcoin C-Lightning instance" \
                "btcpayserver_litecoind" "litecoin-cli.sh" "Command line for your Litecoin instance" \
                "btcpayserver_clightning_litecoin" "litecoin-lightning-cli.sh" "Command line for your Litecoin C-Lightning instance" \
                "btcpayserver_lnd_litecoin" "litecoin-lncli.sh" "Command line for your Litecoin LND instance" \
                "btcpayserver_monacoind" "monacoin-cli.sh" "Command line for your Monacoin instance" \
                "btcpayserver_trezarcoind" "trezarcoin-cli.sh" "Command line for your Trezar instance" \
                "btcpayserver_viacoind" "viacoin-cli.sh" "Command line for your Viacoin instance" \
                "btcpayserver_elementsd" "elements-cli.sh" "Command line for your Elements/Liquid instance" \
                "btcpayserver_monerod" "monero-wallet-cli.sh" "Command line for your Monero instance" \
                "joinmarket" "jm.sh" "Command line for your joinmarket instance" \
                "ndlci_cli" "ndlc-cli.sh" "Command line for NDLC-CLI" \
                "pihole" "pihole.sh" "Command line for running pihole commands" \
                "*" "btcpay-clean.sh" "Command line for deleting old unused docker images" \
                "*" "btcpay-down.sh" "Command line for stopping all services related to BTCPay Server" \
                "*" "btcpay-restart.sh" "Command line for restarting all services related to BTCPay Server" \
                "*" "btcpay-setup.sh" "Command line for restarting all services related to BTCPay Server" \
                "*" "btcpay-up.sh" "Command line for starting all services related to BTCPay Server" \
                "*" "btcpay-admin.sh" "Command line for some administrative operation in BTCPay Server" \
                "*" "btcpay-update.sh" "Command line for updating your BTCPay Server to the latest commit of this repository" \
                "*" "changedomain.sh" "Command line for changing the external domain of your BTCPay Server" \
            )

    i=0
    while [ $i -lt ${#scripts[@]} ]; do
        scriptname="${scripts[$i+1]}"
        dependency="${scripts[$i+0]}"
        comment="${scripts[$i+2]}"

        [ -e /usr/local/bin/$scriptname ] && rm /usr/local/bin/$scriptname
        if [ -e "$scriptname" ]; then
            if [ "$dependency" == "*" ] || ( [ -e "$BTCPAY_DOCKER_COMPOSE" ] && grep -q "$dependency" "$BTCPAY_DOCKER_COMPOSE" ); then
                chmod +x $scriptname
                ln -s "$(pwd)/$scriptname" /usr/local/bin
                echo "Installed $scriptname to /usr/local/bin: $comment"
            fi
        else
            echo "WARNING: Script $scriptname referenced, but not existing"
        fi
        i=`expr $i + 3`
    done
}

btcpay_expand_variables() {
    BTCPAY_CRYPTOS=""
    for i in "$BTCPAYGEN_CRYPTO1" "$BTCPAYGEN_CRYPTO2" "$BTCPAYGEN_CRYPTO3" "$BTCPAYGEN_CRYPTO4" "$BTCPAYGEN_CRYPTO5" "$BTCPAYGEN_CRYPTO5" "$BTCPAYGEN_CRYPTO6" "$BTCPAYGEN_CRYPTO7" "$BTCPAYGEN_CRYPTO8"
    do
        if [ ! -z "$i" ]; then
            if [ ! -z "$BTCPAY_CRYPTOS" ]; then
                BTCPAY_CRYPTOS="$BTCPAY_CRYPTOS;"
            fi
            BTCPAY_CRYPTOS="$BTCPAY_CRYPTOS$i"
        fi
    done
    BTCPAY_ANNOUNCEABLE_HOST=""
    if [[ "$BTCPAY_HOST" != *.local ]] && [[ "$BTCPAY_HOST" != *.lan ]]; then
        BTCPAY_ANNOUNCEABLE_HOST="$BTCPAY_HOST"
    fi
    if [[ "$BTCPAY_LIGHTNING_HOST" ]]; then
        BTCPAY_ANNOUNCEABLE_HOST="$BTCPAY_LIGHTNING_HOST"
    fi
}

# Set .env file
btcpay_update_docker_env() {
btcpay_expand_variables
touch $BTCPAY_ENV_FILE

# In a previous release, BTCPAY_HOST_SSHAUTHORIZEDKEYS was not saved into the .env, so the next update after setup
# with BTCPAY_ENABLE_SSH set, BTCPAY_HOST_SSHAUTHORIZEDKEYS would get empty and break the SSH feature in btcpayserver
# This condition detect this situation, and fix up BTCPAY_HOST_SSHAUTHORIZEDKEYS
if [[ "$BTCPAY_ENABLE_SSH" == "true" ]] && ! [[ "$BTCPAY_HOST_SSHAUTHORIZEDKEYS" ]]; then
    BTCPAY_HOST_SSHAUTHORIZEDKEYS=~/.ssh/authorized_keys
    BTCPAY_HOST_SSHKEYFILE=""
fi

sshd_config="/etc/ssh/sshd_config"
if [[ "$BTCPAY_ENABLE_SSH" == "true" ]] && \
   [[ -f "$sshd_config" ]] && \
   grep -q "PermitRootLogin[[:space:]]no" "$sshd_config"; then
   echo "Updating "$sshd_config" (Change from 'PermitRootLogin no' to 'PermitRootLogin prohibit-password')"
   echo "BTCPay Server needs connection from inside the container to the host in order to run btcpay-update.sh"
   sed -i 's/PermitRootLogin[[:space:]]no/PermitRootLogin prohibit-password/' "$sshd_config"
   service sshd reload
fi

echo "
BTCPAY_PROTOCOL=$BTCPAY_PROTOCOL
BTCPAY_HOST=$BTCPAY_HOST
BTCPAY_LIGHTNING_HOST=$BTCPAY_LIGHTNING_HOST
BTCPAY_ADDITIONAL_HOSTS=$BTCPAY_ADDITIONAL_HOSTS
BTCPAY_ANNOUNCEABLE_HOST=$BTCPAY_ANNOUNCEABLE_HOST
REVERSEPROXY_HTTP_PORT=$REVERSEPROXY_HTTP_PORT
REVERSEPROXY_HTTPS_PORT=$REVERSEPROXY_HTTPS_PORT
REVERSEPROXY_DEFAULT_HOST=$REVERSEPROXY_DEFAULT_HOST
NOREVERSEPROXY_HTTP_PORT=$NOREVERSEPROXY_HTTP_PORT
BTCPAY_IMAGE=$BTCPAY_IMAGE
ACME_CA_URI=$ACME_CA_URI
NBITCOIN_NETWORK=$NBITCOIN_NETWORK
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
LIGHTNING_ALIAS=$LIGHTNING_ALIAS
BTCPAY_SSHTRUSTEDFINGERPRINTS=$BTCPAY_SSHTRUSTEDFINGERPRINTS
BTCPAY_SSHKEYFILE=$BTCPAY_SSHKEYFILE
BTCPAY_SSHAUTHORIZEDKEYS=$BTCPAY_SSHAUTHORIZEDKEYS
BTCPAY_HOST_SSHAUTHORIZEDKEYS=$BTCPAY_HOST_SSHAUTHORIZEDKEYS
LIBREPATRON_HOST=$LIBREPATRON_HOST
ZAMMAD_HOST=$ZAMMAD_HOST
BTCTRANSMUTER_HOST=$BTCTRANSMUTER_HOST
CHATWOOT_HOST=$CHATWOOT_HOST
BTCPAY_CRYPTOS=$BTCPAY_CRYPTOS
WOOCOMMERCE_HOST=$WOOCOMMERCE_HOST
TOR_RELAY_NICKNAME=$TOR_RELAY_NICKNAME
TOR_RELAY_EMAIL=$TOR_RELAY_EMAIL
EPS_XPUB=$EPS_XPUB
LND_WTCLIENT_SWEEP_FEE=$LND_WTCLIENT_SWEEP_FEE
FIREFLY_HOST=$FIREFLY_HOST
LIT_PASSWD=$LIT_PASSWD
TALLYCOIN_APIKEY=$TALLYCOIN_APIKEY
TALLYCOIN_PASSWD=$TALLYCOIN_PASSWD
TALLYCOIN_PASSWD_CLEARTEXT=$TALLYCOIN_PASSWD_CLEARTEXT
CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN" > $BTCPAY_ENV_FILE

env | grep ^BWT_ >> $BTCPAY_ENV_FILE || true
}

docker_compose_set_plugin() {
    echo "set 'docker compose' to /usr/local/bin/docker-compose"
    plugin_path=$(docker info -f '{{ range .ClientInfo.Plugins }}{{ if eq .Name "compose" }}{{ .Path }}{{ end }}{{ end }}' || echo '/usr/libexec/docker/cli-plugins/docker-compose')
    if [[ "$plugin_path" ]] && [ -f "$plugin_path" ]; then
        rm -f "$plugin_path"
        ln -s /usr/local/bin/docker-compose "$plugin_path"
    fi
}

docker_compose_update() {
    # If you change this, update also docker-compose-generator/src/DockerComposeDefinition.cs and the dcg-latest branch
    compose_version="2.23.3"
    if ! [[ -x "$(command -v docker-compose)" ]] || [[ "$(docker-compose version --short)" != "$compose_version" ]]; then
        if ! [[ "$OSTYPE" == "darwin"* ]] && $HAS_DOCKER; then
            echo "Trying to install docker-compose by using docker/compose-bin ($(uname -m))"
            ! [[ -d "dist" ]] && mkdir dist
            container=$(docker create docker/compose-bin:v$compose_version /docker-compose)
            docker cp "$container:/docker-compose" "dist/docker-compose"
            docker rm "$container"
            mv dist/docker-compose /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            rm -rf "dist"
            docker_compose_set_plugin
        fi
    fi
}

version_gt() (
    set +x

    yy_a="$(echo "$1" | cut -d'.' -f1)"
    yy_b="$(echo "$2" | cut -d'.' -f1)"
    if [ "$yy_a" -lt "$yy_b" ]; then
        return 1
    fi
    if [ "$yy_a" -gt "$yy_b" ]; then
        return 0
    fi
    mm_a="$(echo "$1" | cut -d'.' -f2)"
    mm_b="$(echo "$2" | cut -d'.' -f2)"
    mm_a="${mm_a#0}"
    mm_b="${mm_b#0}"
    if [ "${mm_a:-0}" -lt "${mm_b:-0}" ]; then
        return 1
    fi
    if [ "${mm_a:-0}" -gt "${mm_b:-0}" ]; then
        return 0
    fi

    bb_a="$(echo "$1" | cut -d'.' -f3)"
    bb_b="$(echo "$2" | cut -d'.' -f3)"
    bb_a="${bb_a#0}"
    bb_b="${bb_b#0}"
    if [ "${bb_a:-0}" -lt "${bb_b:-0}" ]; then
        return 1
    fi
    if [ "${bb_a:-0}" -gt "${bb_b:-0}" ]; then
        return 0
    fi

    return 1
)

docker_update() {
    if [[ "$(uname -m)" == "armv7l" ]] && cat "/etc/os-release" 2>/dev/null | grep -q "VERSION_CODENAME=buster" 2>/dev/null; then
        if [[ "$(apt list libseccomp2 2>/dev/null)" == *" 2.3"* ]]; then
            echo "Outdated version of libseccomp2, updating... (see: https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/)"
            # https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/
            apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138 0E98404D386FA1D9 6ED0E7B82643E131
            echo 'deb http://httpredir.debian.org/debian buster-backports main contrib non-free' | sudo tee -a /etc/apt/sources.list.d/debian-backports.list
            apt update
            apt install libseccomp2 -t buster-backports
        fi
    fi

    if $HAS_DOCKER; then
        docker_version="$(docker version -f "{{ .Server.Version }}")"
        if version_gt "20.10.10" "$docker_version"; then
            echo "Updating docker, old version can't run some images (https://docs.linuxserver.io/FAQ/#jammy)"
            echo \
            "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            "$(lsb_release -cs)" stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

            if apt-get update | grep -q "NO_PUBKEY"; then
                echo "Installing new docker key..."
                mkdir -p /etc/apt/keyrings
                rm -f /etc/apt/keyrings/docker.gpg
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                apt-get update
            fi

            apt-get install --only-upgrade -y docker-ce docker-ce-cli containerd.io

            # Possible that old distro like xenial doesn't have it anymore, if so, just take
            # the next distrib
            docker_version="$(docker version -f "{{ .Server.Version }}")"
            if version_gt "20.10.10" "$docker_version"; then
                echo "Updating docker, with bionic's version"
                echo \
                "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                bionic stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
                mkdir -p /etc/apt/keyrings
                rm -f /etc/apt/keyrings/docker.gpg
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                apt-get update
                apt-get install --only-upgrade -y docker-ce docker-ce-cli containerd.io
            fi

            docker_compose_set_plugin
        fi
    fi
    docker_compose_update
}

btcpay_up() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    docker-compose -f $BTCPAY_DOCKER_COMPOSE up --remove-orphans -d -t "${COMPOSE_HTTP_TIMEOUT:-180}"
    popd > /dev/null
}

btcpay_pull() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    docker-compose -f "$BTCPAY_DOCKER_COMPOSE" pull
    popd > /dev/null
}

btcpay_down() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    docker-compose -f $BTCPAY_DOCKER_COMPOSE down -t "${COMPOSE_HTTP_TIMEOUT:-180}"
    popd > /dev/null
}

btcpay_restart() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    docker-compose -f $BTCPAY_DOCKER_COMPOSE restart -t "${COMPOSE_HTTP_TIMEOUT:-180}"
    btcpay_up
    popd > /dev/null
}

btcpay_dump_db() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    local file_path=${1:-"postgres-$(date "+%Y%m%d-%H%M%S").sql.gz"}
    docker exec $(docker ps -a -q -f "name=postgres_1") pg_dumpall -c -U postgres | gzip > "$file_path"
    popd > /dev/null
}
