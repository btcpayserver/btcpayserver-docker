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
export BTCPAY_ENABLE_SSH="true"
export TRUST_DOWNSTREAM_PROXY="true"

if "$repo_dir/btcpay-host" changedomain $'example.com\nPROMPT_COMMAND=id' 2> "$test_dir/error"; then
    printf 'btcpay-host must reject an invalid domain\n' >&2
    exit 1
fi
grep -Fxq 'The domain must be a valid domain name without a protocol.' "$test_dir/error"

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
