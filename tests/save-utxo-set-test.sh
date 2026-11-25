#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

# Redirect the script's hardcoded volume path into an isolated fixture.
real_volume=/var/lib/docker/volumes/generated_bitcoin_datadir/_data
volume="$test_dir/volume"
work_dir="$test_dir/FastSync"
new_snapshot=utxo-snapshot-bitcoin-mainnet-900000.tar
mkdir -p "$test_dir/bin" "$volume" "$work_dir/.ssh"
sed "s#$real_volume#$volume#g" "$repo_dir/contrib/FastSync/save-utxo-set.sh" > "$work_dir/save-utxo-set.sh"
if grep -qF /var/lib/docker "$work_dir/save-utxo-set.sh"; then
    printf 'Snapshot test must not reference real Docker volumes.\n' >&2
    exit 1
fi
touch "$work_dir/utxo-sets" "$work_dir/.ssh/authorized_keys"

for command in btcpay-down.sh btcpay-up.sh; do
    printf '#!/bin/bash\nexit 0\n' > "$test_dir/bin/$command"
done
cat > "$test_dir/bin/docker-compose" <<'EOF'
#!/bin/bash
set -euo pipefail
[ "$1" = -f ] && [ "$2" = "$BTCPAY_DOCKER_COMPOSE" ]
touch "$TEST_VOLUME/$TEST_NEW_SNAPSHOT"
EOF
chmod +x "$test_dir/bin/"*

# A container controls names in its mounted volume, not the host's working
# directory. Exercise both the normal working directory and one with spaces.
for cwd in "$work_dir" "$test_dir/root home"; do
    mkdir -p "$cwd/.ssh"
    cp "$repo_dir/contrib/FastSync/save-utxo-set-in-bitcoind.sh" "$cwd/"
    touch "$cwd/keep" "$cwd/.ssh/authorized_keys"
    rm -f -- "$volume/"*
    touch "$volume/utxo-snapshot-old.tar" "$volume/utxo-snapshot-0 -rf * .ssh"
    output="$(cd "$cwd" && env -u AZURE_STORAGE_CONNECTION_STRING \
        PATH="$test_dir/bin:$PATH" \
        BTCPAY_ENV_FILE="$cwd/.env" \
        BTCPAY_DOCKER_COMPOSE="$cwd/docker-compose.yml" \
        NBITCOIN_NETWORK=mainnet \
        TEST_VOLUME="$volume" \
        TEST_NEW_SNAPSHOT="$new_snapshot" \
        bash "$work_dir/save-utxo-set.sh" 2>&1)"
    for path in keep .ssh/authorized_keys save-utxo-set-in-bitcoind.sh; do
        if [ ! -f "$cwd/$path" ]; then
            printf 'Snapshot cleanup removed a file outside its volume: %s\n' "$path" >&2
            exit 1
        fi
    done
    [ "$(ls -A "$volume")" = "$new_snapshot" ]
    grep -Fq "File at: $volume/$new_snapshot" <<< "$output"
done

printf 'FastSync snapshot tests passed\n'
