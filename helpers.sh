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
                "*" "btcpay-update.sh" "Command line for updating your BTCPay Server to the latest commit of this repository" \
                "*" "changedomain.sh" "Command line for changing the external domain of your BTCPay Server" \
            )

    i=0
    while [ $i -lt ${#scripts[@]} ]; do
        scriptname="${scripts[$i+1]}"
        dependency="${scripts[$i+0]}"
        comment="${scripts[$i+2]}"

        [ -e /usr/bin/$scriptname ] && rm /usr/bin/$scriptname
        if [ -e "$scriptname" ]; then
            if [ "$dependency" == "*" ] || grep -q "$dependency" "$BTCPAY_DOCKER_COMPOSE"; then
                chmod +x $scriptname
                ln -s "$(pwd)/$scriptname" /usr/bin
                echo "Installed $scriptname to /usr/bin: $comment"
            fi
        else
            echo "WARNING: Script $scriptname referenced, but not existing"
        fi
        i=`expr $i + 3`
    done
}