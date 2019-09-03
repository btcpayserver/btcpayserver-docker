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
}

# Set .env file
btcpay_update_docker_env() {
btcpay_expand_variables
touch $BTCPAY_ENV_FILE
echo "
BTCPAY_PROTOCOL=$BTCPAY_PROTOCOL
BTCPAY_HOST=$BTCPAY_HOST
BTCPAY_ADDITIONAL_HOSTS=$BTCPAY_ADDITIONAL_HOSTS
BTCPAY_ANNOUNCEABLE_HOST=$BTCPAY_ANNOUNCEABLE_HOST
REVERSEPROXY_HTTP_PORT=$REVERSEPROXY_HTTP_PORT
REVERSEPROXY_HTTPS_PORT=$REVERSEPROXY_HTTPS_PORT
REVERSEPROXY_DEFAULT_HOST=$REVERSEPROXY_DEFAULT_HOST
BTCPAY_IMAGE=$BTCPAY_IMAGE
ACME_CA_URI=$ACME_CA_URI
NBITCOIN_NETWORK=$NBITCOIN_NETWORK
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
LIGHTNING_ALIAS=$LIGHTNING_ALIAS
BTCPAY_SSHTRUSTEDFINGERPRINTS=$BTCPAY_SSHTRUSTEDFINGERPRINTS
BTCPAY_SSHKEYFILE=$BTCPAY_SSHKEYFILE
BTCPAY_SSHAUTHORIZEDKEYS=$BTCPAY_SSHAUTHORIZEDKEYS
LIBREPATRON_HOST=$LIBREPATRON_HOST
BTCTRANSMUTER_HOST=$BTCTRANSMUTER_HOST
BTCPAY_CRYPTOS=$BTCPAY_CRYPTOS
WOOCOMMERCE_HOST=$WOOCOMMERCE_HOST
TOR_RELAY_NICKNAME=$TOR_RELAY_NICKNAME
TOR_RELAY_EMAIL=$TOR_RELAY_EMAIL" > $BTCPAY_ENV_FILE
}

btcpay_up() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    docker-compose -f $BTCPAY_DOCKER_COMPOSE up --remove-orphans -d -t "${COMPOSE_HTTP_TIMEOUT:-180}"
    # Depending on docker-compose, either the timeout does not work, or "compose -d and --timeout cannot be combined"
    if ! [ $? -eq 0 ]; then
        docker-compose -f $BTCPAY_DOCKER_COMPOSE up --remove-orphans -d
    fi
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
    # Depending on docker-compose, the timeout does not work.
    if ! [ $? -eq 0 ]; then
        docker-compose -f $BTCPAY_DOCKER_COMPOSE down
    fi
    popd > /dev/null
}

btcpay_restart() {
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    docker-compose -f $BTCPAY_DOCKER_COMPOSE restart -t "${COMPOSE_HTTP_TIMEOUT:-180}"
    # Depending on docker-compose, the timeout does not work.
    if ! [ $? -eq 0 ]; then
        docker-compose -f $BTCPAY_DOCKER_COMPOSE restart
    fi
    popd > /dev/null
}