#!/bin/bash

set -eo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

cp "$repo_dir/build.sh" "$test_dir/build.sh"
mkdir "$test_dir/Generated" "$test_dir/bin"

cat > "$test_dir/helpers.sh" <<'EOF'
btcpay_setup_ssh() {
    printf 'setup-ssh\n' >> "$ACTION_LOG"
}
EOF

cat > "$test_dir/generate-secrets.sh" <<'EOF'
#!/bin/bash
printf 'generate-secrets\n' >> "$ACTION_LOG"
EOF

cat > "$test_dir/btcpay-routes" <<'EOF'
#!/bin/bash
printf 'sync-routes\n' >> "$ACTION_LOG"
EOF

cat > "$test_dir/bin/docker" <<'EOF'
#!/bin/bash
exit 0
EOF

chmod +x "$test_dir/build.sh" "$test_dir/generate-secrets.sh" \
    "$test_dir/btcpay-routes" "$test_dir/bin/docker"

export ACTION_LOG="$test_dir/actions.log"
export BTCPAYGEN_REVERSEPROXY="nginx"

: > "$ACTION_LOG"
help_output="$(
    cd "$test_dir"
    PATH="$test_dir/bin:$PATH" ./build.sh --help
)"
expected_help="Usage: ./build.sh [--setup-ssh] [--sync-routes]

Options:
  --setup-ssh    Configure BTCPay Server host SSH integration
  --sync-routes  Synchronize generated Nginx routes
  -h, --help     Show this help"
if [[ "$help_output" != "$expected_help" ]] || [[ -s "$ACTION_LOG" ]]; then
    printf 'build.sh help must describe the supported options without performing actions\n' >&2
    exit 1
fi

: > "$ACTION_LOG"
(
    cd "$test_dir"
    PATH="$test_dir/bin:$PATH" ./build.sh
)
if grep -Eq '^(setup-ssh|sync-routes)$' "$ACTION_LOG"; then
    printf 'build.sh must not configure SSH or synchronize routes by default\n' >&2
    exit 1
fi

: > "$ACTION_LOG"
(
    cd "$test_dir"
    PATH="$test_dir/bin:$PATH" ./build.sh --setup-ssh --sync-routes
)
grep -Fxq 'setup-ssh' "$ACTION_LOG"
grep -Fxq 'sync-routes' "$ACTION_LOG"

: > "$ACTION_LOG"
if (
    cd "$test_dir"
    PATH="$test_dir/bin:$PATH" ./build.sh --unsupported
) 2> /dev/null; then
    printf 'build.sh must reject unsupported arguments\n' >&2
    exit 1
fi
if [[ -s "$ACTION_LOG" ]]; then
    printf 'build.sh must reject unsupported arguments before performing actions\n' >&2
    exit 1
fi

printf 'build.sh tests passed\n'
