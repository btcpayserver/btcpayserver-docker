install_tooling() {
    scripts=( \
                "btcpayserver_bitcoind" "bitcoin-cli.sh" "Command line for your Bitcoin instance" \
                "btcpayserver_clightning_bitcoin" "bitcoin-lightning-cli.sh" "Command line for your Bitcoin C-Lightning instance" \
                "btcpayserver_lnd_bitcoin" "bitcoin-lncli.sh" "Command line for your Bitcoin LND instance" \
                "btcpayserver_dashd" "dash-cli.sh" "Command line for your Dash instance" \
                "btcpayserver_dogecoind" "dogecoin-cli.sh" "Command line for your Dogecoin instance" \
                "btcpayserver_feathercoind" "feathercoin-cli.sh" "Command line for your Feathercoin instance" \
                "btcpayserver_groestlcoind" "groestlcoin-cli.sh" "Command line for your Groestlcoin instance" \
                "btcpayserver_clightning_groestlcoin" "groestlcoin-lightning-cli.sh" "Command line for your Groestlcoin C-Lightning instance" \
                "btcpayserver_litecoind" "litecoin-cli.sh" "Command line for your Litecoin instance" \
                "btcpayserver_monacoind" "monacoin-cli.sh" "Command line for your Monacoin instance" \
                "btcpayserver_elementsd" "elements-cli.sh" "Command line for your Elements/Liquid instance" \
                "btcpayserver_monerod" "monero-wallet-cli.sh" "Command line for your Monero instance" \
                "btcpayserver_beldexd" "beldex-wallet-cli.sh" "Command line for your Beldex instance" \
                "pihole" "pihole.sh" "Command line for running pihole commands" \
                "*" "btcpay-host" "Command line exposing the services of the host (see https://github.com/btcpayserver/btcpayserver/pull/7511)" \
                "*" "btcpay-fragments" "Command line for managing Docker Compose fragments" \
                "*" "btcpay-routes" "Command line for managing optional nginx routes" \
                "*" "btcpay-clean.sh" "Command line for deleting old unused docker images" \
                "*" "btcpay-down.sh" "Command line for stopping all services related to BTCPay Server" \
                "*" "btcpay-restart.sh" "Command line for restarting all services related to BTCPay Server" \
                "*" "btcpay-setup.sh" "Command line for restarting all services related to BTCPay Server" \
                "*" "switch-node.sh" "Command line for switching the Bitcoin node implementation" \
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

        if [ -e "/usr/local/bin/$scriptname" ] || [ -L "/usr/local/bin/$scriptname" ]; then
            rm -f -- "/usr/local/bin/$scriptname" || return 1
        fi
        if [ -e "$scriptname" ]; then
            if [ "$dependency" == "*" ] || ( [ -e "$BTCPAY_DOCKER_COMPOSE" ] && grep -q "$dependency" "$BTCPAY_DOCKER_COMPOSE" ); then
                chmod +x "$scriptname" || return 1
                ln -s "$(pwd)/$scriptname" "/usr/local/bin/$scriptname" || return 1
                echo "Installed $scriptname to /usr/local/bin: $comment"
            fi
        else
            echo "WARNING: Script $scriptname referenced, but not existing"
        fi
        i=`expr $i + 3`
    done
}

remove_fragments() {
    local value="$1"
    shift
    local result=""
    local fragment
    local fragments
    local excluded_fragment

    value="${value//,/;}"
    IFS=';' read -ra fragments <<< "$value"
    for fragment in "${fragments[@]}"; do
        fragment="${fragment//[[:space:]]/}"
        if [ -z "$fragment" ]; then
            continue
        fi

        for excluded_fragment in "$@"; do
            if [ "$fragment" == "$excluded_fragment" ]; then
                continue 2
            fi
        done

        if [ -z "$result" ]; then
            result="$fragment"
        else
            result="$result;$fragment"
        fi
    done

    echo "$result"
}

add_fragments() {
    local value="$1"
    shift
    local result
    local fragment

    result="$(remove_fragments "$value" "$@")"
    for fragment in "$@"; do
        if [ -z "$fragment" ]; then
            continue
        fi

        if [ -z "$result" ]; then
            result="$fragment"
        else
            result="$result;$fragment"
        fi
    done

    echo "$result"
}

btcpay_setup_ssh() {
    local ssh_dir="/root/.ssh"
    local key_file="$ssh_dir/btcpay_host_id_ed25519"
    local authorized_keys="$ssh_dir/authorized_keys"
    local authorized_keys_tmp="$ssh_dir/authorized_keys.tmp"
    local public_key

    if [ "$(id -u)" -ne 0 ]; then
        echo "BTCPay host integration requires root access to update $authorized_keys"
        return 1
    fi

    mkdir -p "$ssh_dir" || return 1
    chmod 700 "$ssh_dir" || return 1

    if [ ! -f "$authorized_keys" ]; then
        touch "$authorized_keys" || return 1
        chmod 600 "$authorized_keys" || return 1
    fi
    cp "$authorized_keys" "$authorized_keys_tmp" || return 1
    if ! sed -i '/ btcpayserver$/d' "$authorized_keys_tmp" ||
       ! sed -i '/ btcpay-host$/d' "$authorized_keys_tmp"; then
        rm -f -- "$authorized_keys_tmp"
        return 1
    fi

    if [ ! -f "$key_file" ]; then
        if ! ssh-keygen -t ed25519 -f "$key_file" -N "" -C "btcpay-host" -q; then
            rm -f -- "$authorized_keys_tmp"
            return 1
        fi
    fi
    if [ ! -f "$key_file.pub" ]; then
        if ! ssh-keygen -y -f "$key_file" > "$key_file.pub"; then
            rm -f -- "$authorized_keys_tmp" "$key_file.pub"
            return 1
        fi
    fi
    if ! public_key="$(cat "$key_file.pub")"; then
        rm -f -- "$authorized_keys_tmp"
        return 1
    fi

    if ! printf 'restrict,command="%s" %s\n' \
            "${BTCPAY_BASE_DIRECTORY}/btcpayserver-docker/Generated/btcpay-host-proxy" \
            "$public_key" >> "$authorized_keys_tmp"; then
        rm -f -- "$authorized_keys_tmp"
        return 1
    fi

    if ! cmp -s "$authorized_keys_tmp" "$authorized_keys"; then
        echo "$authorized_keys updated"
        mv "$authorized_keys_tmp" "$authorized_keys" || return 1
        chmod 600 "$authorized_keys" || return 1
    else
        rm -f -- "$authorized_keys_tmp" || return 1
    fi
}

btcpay_expand_variables() {
    BTCPAY_CRYPTOS=""
    for i in "$BTCPAYGEN_CRYPTO1" "$BTCPAYGEN_CRYPTO2" "$BTCPAYGEN_CRYPTO3" "$BTCPAYGEN_CRYPTO4" "$BTCPAYGEN_CRYPTO5" "$BTCPAYGEN_CRYPTO6" "$BTCPAYGEN_CRYPTO7" "$BTCPAYGEN_CRYPTO8" "$BTCPAYGEN_CRYPTO9"
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

local variable
local value
local env_variables=(
    BTCPAY_PROTOCOL
    BTCPAY_HOST
    BTCPAY_LIGHTNING_HOST
    BTCPAY_ADDITIONAL_HOSTS
    BTCPAY_ANNOUNCEABLE_HOST
    REVERSEPROXY_HTTP_PORT
    REVERSEPROXY_HTTPS_PORT
    REVERSEPROXY_DEFAULT_HOST
    TRUST_DOWNSTREAM_PROXY
    NOREVERSEPROXY_HTTP_PORT
    BTCPAY_IMAGE
    BTCPAY_UPDATE_CLEAN
    ACME_CA_URI
    NBITCOIN_NETWORK
    LETSENCRYPT_EMAIL
    LIGHTNING_ALIAS
    ZAMMAD_HOST
    BTCPAY_CRYPTOS
    WOOCOMMERCE_HOST
    TOR_RELAY_NICKNAME
    TOR_RELAY_EMAIL
    LND_WTCLIENT_SWEEP_FEE
    LIT_PASSWD
    CLOUDFLARE_TUNNEL_TOKEN
)

for variable in "${env_variables[@]}"; do
    value="${!variable-}"
    if [[ "$value" == *$'\n'* ]] || [[ "$value" == *$'\r'* ]]; then
        echo "Refusing to write $variable: environment values cannot contain newlines." >&2
        return 1
    fi
done

sshd_config="/etc/ssh/sshd_config"
if [[ -f "$sshd_config" ]] && \
   grep -q "PermitRootLogin[[:space:]]no" "$sshd_config"; then
   echo "Updating "$sshd_config" (Change from 'PermitRootLogin no' to 'PermitRootLogin prohibit-password')"
   echo "BTCPay Server needs connection from inside the container to the host in order to run btcpay-update.sh"
   sed -i 's/PermitRootLogin[[:space:]]no/PermitRootLogin prohibit-password/' "$sshd_config"
   service sshd reload
fi

for variable in "${env_variables[@]}"; do
    printf '%s=%s\n' "$variable" "${!variable-}"
done > "$BTCPAY_ENV_FILE"
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
    compose_version="2.40.3"
    if ! [[ -x "$(command -v docker-compose)" ]] || [[ "$(docker-compose version --short)" != "$compose_version" ]]; then
        if $HAS_DOCKER; then
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

# Save project container output before replacement, retaining five private,
# compressed snapshots.
btcpay_archive_logs() (
    set -o pipefail
    local archive_dir archive_file
    local archives

    # Logs can contain sensitive information. Keep archives outside the checkout.
    umask 077
    archive_dir="$BTCPAY_BASE_DIRECTORY/btcpay-update-logs"
    mkdir -p "$archive_dir" && chmod 700 "$archive_dir" || return 1
    archive_file="$archive_dir/update-$(date -u +%Y%m%dT%H%M%SZ).log.gz"

    if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" logs --no-color --timestamps |
        gzip > "$archive_file"; then
        return 1
    fi

    echo "Container logs saved to $archive_file"

    shopt -s nullglob
    archives=("$archive_dir"/update-*.log.gz)
    while [ "${#archives[@]}" -gt 5 ]; do
        rm -f -- "${archives[0]}" || return 1
        archives=("${archives[@]:1}")
    done
)

btcpay_up() {
    local status
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    if docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up --remove-orphans -d -t "${COMPOSE_HTTP_TIMEOUT:-180}"; then
        status=0
    else
        status=$?
    fi
    popd > /dev/null
    [ "$status" -eq 0 ] || return "$status"
    ensure_reverse_proxy_up
}

# nginx can lose a race against the letsencrypt companion while the stack is
# being recreated. The companion drops the certificate symlinks of every vhost
# whose container is momentarily down, nginx then starts with a config that
# still points at them and exits:
#
#   [emerg] cannot load certificate "/etc/nginx/certs/<host>.crt"
#
# Docker does not bring it back, because compose had stopped it on purpose
# (hasBeenManuallyStopped), and the companion refuses to repair anything while
# nginx is down ("nginx-proxy container nginx isn't running"). The deadlock
# therefore outlives the update: compose reports success, every other container
# is healthy, and the server answers nothing on ports 80/443 until a human
# notices. By then docker-gen has already regenerated a config that falls back
# to the default certificate, so starting nginx once more breaks the loop and
# lets the companion restore the symlinks on its next run.
ensure_reverse_proxy_up() {
    [[ "$BTCPAYGEN_REVERSEPROXY" == "nginx" ]] || return 0
    docker inspect nginx > /dev/null 2>&1 || return 0

    local status
    local i
    # Give it a moment to settle, but do not sit through the whole grace period
    # once it has already given up.
    for i in $(seq 1 6); do
        status="$(docker inspect -f '{{.State.Status}}' nginx 2>/dev/null)"
        case "$status" in
            running) return 0 ;;
            exited|dead) break ;;
        esac
        sleep 5
    done

    echo "Warning: the nginx container is '$status' after the stack was brought up, starting it again..."
    docker start nginx > /dev/null 2>&1
    sleep 5

    for i in $(seq 1 6); do
        status="$(docker inspect -f '{{.State.Status}}' nginx 2>/dev/null)"
        case "$status" in
            running) echo "Info: nginx is running again."; return 0 ;;
            exited|dead) break ;;
        esac
        sleep 5
    done

    echo "Error: nginx is '$status', this server will not answer on ports 80/443. Last lines of its log:"
    docker logs --tail 10 nginx 2>&1 | sed 's/^/    /'
    return 1
}

btcpay_pull() {
    local status
    pushd . > /dev/null
    cd "$(dirname "$BTCPAY_ENV_FILE")"
    if docker-compose -f "$BTCPAY_DOCKER_COMPOSE" pull; then
        status=0
    else
        status=$?
    fi
    popd > /dev/null
    return "$status"
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
