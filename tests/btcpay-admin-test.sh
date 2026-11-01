#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

cat > "$test_dir/docker" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ "$1" = ps ]; then
    printf 'postgres-container\n'
    exit 0
fi

[ "$1" = exec ]
printf '%s\0' "$@" > "$BTCPAY_ADMIN_TEST_CAPTURE"
if [ -n "${BTCPAY_ADMIN_TEST_DATABASES:-}" ]; then
    while [ "$#" -gt 0 ]; do
        if [ "$1" = -d ]; then
            printf '%s\n' "$2" >> "$BTCPAY_ADMIN_TEST_DATABASES"
            break
        fi
        shift
    done
fi
cat > "$BTCPAY_ADMIN_TEST_STATEMENT"
EOF
chmod +x "$test_dir/docker"

payload="attacker@example.com'); SELECT pg_sleep(10); --"
capture="$test_dir/docker-args"
statement="$test_dir/statement.sql"
BTCPAY_ADMIN_TEST_CAPTURE="$capture" \
BTCPAY_ADMIN_TEST_STATEMENT="$statement" \
PATH="$test_dir:$PATH" \
    bash "$repo_dir/btcpay-admin.sh" set-user-admin "$payload"

mapfile -d '' arguments < "$capture"
email_argument_found=false
interactive_stdin_found=false
stdin_file_found=false
for argument in "${arguments[@]}"; do
    if [ "$argument" = "--set=email=$payload" ]; then
        email_argument_found=true
    elif [[ "$argument" == *"$payload"* ]]; then
        printf 'Email payload was interpolated into another psql argument\n' >&2
        exit 1
    fi
    if [ "$argument" = "-i" ]; then
        interactive_stdin_found=true
    fi
    if [ "$argument" = "-f" ]; then
        stdin_file_found=true
    fi
done

[ "$email_argument_found" = true ]
[ "$interactive_stdin_found" = true ]
[ "$stdin_file_found" = true ]
grep -F "upper(:'email')" "$statement" >/dev/null
if grep -F "$payload" "$statement" >/dev/null; then
    printf 'Email payload was interpolated into the SQL statement\n' >&2
    exit 1
fi
# Each administrative operation must use the database for the deployment's
# network, including all three statements used to disable multifactor auth.
for network in unset empty mainnet testnet signet regtest; do
    for command in set-user-admin disable-multifactor reset-server-policy; do
        databases="$test_dir/databases"
        : > "$databases"
        (
            unset NBITCOIN_NETWORK
            if [ "$network" != unset ]; then
                NBITCOIN_NETWORK="$network"
                [ "$network" != empty ] || NBITCOIN_NETWORK=""
                export NBITCOIN_NETWORK
            fi
            BTCPAY_ADMIN_TEST_CAPTURE="$capture" \
            BTCPAY_ADMIN_TEST_STATEMENT="$statement" \
            BTCPAY_ADMIN_TEST_DATABASES="$databases" \
            PATH="$test_dir:$PATH" \
                bash "$repo_dir/btcpay-admin.sh" "$command" admin@example.com
        )
        expected_network="$network"
        case "$network" in
            unset|empty) expected_network=mainnet ;;
        esac
        expected_count=1
        [ "$command" != disable-multifactor ] || expected_count=3
        mapfile -t selected_databases < "$databases"
        [ "${#selected_databases[@]}" -eq "$expected_count" ]
        for database in "${selected_databases[@]}"; do
            if [ "$database" != "btcpayserver$expected_network" ]; then
                printf '%s (%s): expected database btcpayserver%s, got %s\n' \
                    "$command" "$network" "$expected_network" "$database" >&2
                exit 1
            fi
        done
        printf 'PASS %s network=%s queries=%s\n' "$command" "$network" "$expected_count"
    done
done
# A usage-only invocation must not contact Docker or execute SQL.
rm -f "$capture" "$statement"
BTCPAY_ADMIN_TEST_CAPTURE="$capture" \
BTCPAY_ADMIN_TEST_STATEMENT="$statement" \
PATH="$test_dir:$PATH" \
    bash "$repo_dir/btcpay-admin.sh" unknown-command > "$test_dir/usage"
grep -F 'Commands:' "$test_dir/usage" >/dev/null
[ ! -e "$capture" ]
[ ! -e "$statement" ]
printf 'PASS unknown command does not query a database\n'
printf 'BTCPay admin tests passed\n'
