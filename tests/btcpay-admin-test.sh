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
printf 'BTCPay admin tests passed\n'
