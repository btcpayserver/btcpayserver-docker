#!/bin/bash

set -eo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

# shellcheck source=../helpers.sh
. "$repo_dir/helpers.sh"

export BTCPAY_ENV_FILE="$test_dir/.env"
export BTCPAY_HOST="example.com"
export BTCPAYGEN_CRYPTO1="btc"
export TRUST_DOWNSTREAM_PROXY="true"

for BTCPAYGEN_EXCLUDE_FRAGMENTS in 'btcpay-host' 'opt-add-tor;btcpay-host' ' BTCPay-Host.yml , opt-add-tor'; do
    if ! btcpay_fragment_is_excluded btcpay-host; then
        printf 'btcpay-host must be excluded by %q\n' "$BTCPAYGEN_EXCLUDE_FRAGMENTS" >&2
        exit 1
    fi
done
for BTCPAYGEN_EXCLUDE_FRAGMENTS in '' 'opt-add-tor' 'btcpay-hostx;not-btcpay-host'; do
    if btcpay_fragment_is_excluded btcpay-host; then
        printf 'btcpay-host must not be excluded by %q\n' "$BTCPAYGEN_EXCLUDE_FRAGMENTS" >&2
        exit 1
    fi
done
unset BTCPAYGEN_EXCLUDE_FRAGMENTS

if "$repo_dir/btcpay-host" changedomain $'example.com\nPROMPT_COMMAND=id' 2> "$test_dir/error"; then
    printf 'btcpay-host must reject an invalid domain\n' >&2
    exit 1
fi
grep -Fxq 'The domain must be a valid domain name without a protocol.' "$test_dir/error"

mkdir "$test_dir/bin"
cat > "$test_dir/bin/btcpay-host" <<'EOF'
#!/bin/bash
printf '%s\0' "$@"
EOF
chmod +x "$test_dir/bin/btcpay-host"

proxy="$repo_dir/Generated/btcpay-host-proxy"
arguments=('env' 'space separated' "single'quote" "\$HOME; *" $'embedded\nnewline' $'trailing newline\n' '')
jq -cn --args '$ARGS.positional' "${arguments[@]}" |
    PATH="$test_dir/bin:$PATH" "$proxy" > "$test_dir/actual-arguments"
printf '%s\0' "${arguments[@]}" > "$test_dir/expected-arguments"
cmp -s "$test_dir/expected-arguments" "$test_dir/actual-arguments"

injected_file="$test_dir/injected"
if jq -cn '"env", ["/usr/bin/touch", $path]' --arg path "$injected_file" |
    PATH="$test_dir/bin:$PATH" "$proxy" > /dev/null 2> "$test_dir/error"; then
    printf 'btcpay-host-proxy must reject multiple JSON documents\n' >&2
    exit 1
fi
if [ -e "$injected_file" ]; then
    printf 'btcpay-host-proxy executed a command from a second JSON document\n' >&2
    exit 1
fi
grep -Fxq 'Expected exactly one JSON array containing only strings' "$test_dir/error"

if printf '["env", 1]\n' |
    PATH="$test_dir/bin:$PATH" "$proxy" > /dev/null 2> "$test_dir/error"; then
    printf 'btcpay-host-proxy must reject non-string arguments\n' >&2
    exit 1
fi
if printf '["env", "\\u0000"]\n' |
    PATH="$test_dir/bin:$PATH" "$proxy" > /dev/null 2> "$test_dir/error"; then
    printf 'btcpay-host-proxy must reject NUL arguments\n' >&2
    exit 1
fi

btcpay_update_docker_env
grep -Fxq 'BTCPAY_HOST=example.com' "$BTCPAY_ENV_FILE"
grep -Fxq 'TRUST_DOWNSTREAM_PROXY=true' "$BTCPAY_ENV_FILE"

cp "$BTCPAY_ENV_FILE" "$test_dir/expected.env"
export BTCPAY_HOST=$'example.com\nPROMPT_COMMAND=id'
if btcpay_update_docker_env; then
    printf 'A value containing a newline must be rejected\n' >&2
    exit 1
fi
cmp -s "$test_dir/expected.env" "$BTCPAY_ENV_FILE"

export BTCPAY_HOST=$'example.com\rPROMPT_COMMAND=id'
if btcpay_update_docker_env; then
    printf 'A value containing a carriage return must be rejected\n' >&2
    exit 1
fi
cmp -s "$test_dir/expected.env" "$BTCPAY_ENV_FILE"

printf 'Environment persistence tests passed\n'
