#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

deployment_dir="$test_dir/deployment"
test_repo="$deployment_dir/btcpayserver-docker"
profile="$test_dir/btcpay-env.sh"
setup_calls_file="$test_dir/setup-calls"
setup_environment_file="$test_dir/setup-environment"
mkdir -p "$test_dir/bin" "$test_repo/docker-compose-generator" "$test_repo/Generated"
ln -s "$repo_dir/btcpay-switch" "$test_dir/bin/btcpay-switch"
ln -s "$repo_dir/helpers.sh" "$test_repo/helpers.sh"
ln -s "$repo_dir/docker-compose-generator/crypto-definitions.json" \
    "$test_repo/docker-compose-generator/crypto-definitions.json"
ln -s "$repo_dir/docker-compose-generator/docker-fragments" \
    "$test_repo/docker-compose-generator/docker-fragments"

write_id() {
    cat > "$test_dir/bin/id" <<EOF
#!/bin/bash
if [ "\${1:-}" = "-u" ]; then
    printf '%s\n' '$1'
else
    /usr/bin/id "\$@"
fi
EOF
    chmod +x "$test_dir/bin/id"
}

write_id 0

cat > "$test_repo/btcpay-setup.sh" <<'EOF'
#!/bin/bash
printf 'setup invoked\n' >&2
printf 'call\n' >> "$TEST_SETUP_CALLS"
printf '%s\n' "${BTCPAY_IMAGE-unset}" >> "$TEST_SETUP_ENVIRONMENT"
{
    printf 'export BTCPAY_BASE_DIRECTORY=%q\n' "$TEST_BASE_DIRECTORY"
    for i in {1..9}; do
        variable="BTCPAYGEN_CRYPTO$i"
        printf 'export %s=%q\n' "$variable" "${!variable:-}"
    done
    printf 'export BTCPAYGEN_LIGHTNING=%q\n' "${BTCPAYGEN_LIGHTNING:-}"
    printf 'export BTCPAYGEN_ADDITIONAL_FRAGMENTS=%q\n' "${BTCPAYGEN_ADDITIONAL_FRAGMENTS:-}"
    printf 'export BTCPAYGEN_EXCLUDE_FRAGMENTS=%q\n' "${BTCPAYGEN_EXCLUDE_FRAGMENTS:-}"
    printf 'export BTCPAY_IMAGE=%q\n' "${BTCPAY_IMAGE:-}"
} > "$BTCPAY_SWITCH_PROFILE"
if [ "${TEST_SETUP_FAIL:-false}" = "true" ]; then
    printf 'setup failed\n' >&2
    return 1
fi
return 0
EOF
chmod +x "$test_repo/btcpay-setup.sh"

write_profile() {
    local lightning="$1"
    local additional="${2:-}"
    local excluded="${3:-}"
    local crypto1="${4:-btc}"
    local crypto2="${5:-}"
    {
        printf 'export BTCPAY_BASE_DIRECTORY=%q\n' "$deployment_dir"
        printf 'export BTCPAYGEN_CRYPTO1=%q\n' "$crypto1"
        printf 'export BTCPAYGEN_CRYPTO2=%q\n' "$crypto2"
        for i in {3..9}; do
            printf 'export BTCPAYGEN_CRYPTO%s=%q\n' "$i" ""
        done
    printf 'export BTCPAYGEN_LIGHTNING=%q\n' "$lightning"
    printf 'export BTCPAYGEN_ADDITIONAL_FRAGMENTS=%q\n' "$additional"
    printf 'export BTCPAYGEN_EXCLUDE_FRAGMENTS=%q\n' "$excluded"
    printf 'export BTCPAY_IMAGE=%q\n' "saved-image"
    } > "$profile"
}

write_manifest() {
    jq -n --args '$ARGS.positional | {fragments:.}' -- "$@" > "$test_repo/Generated/manifest.json"
}

setup_calls() {
    if [ -f "$setup_calls_file" ]; then
        wc -l < "$setup_calls_file"
    else
        printf '0\n'
    fi
}

profile_value() {
    (
        # shellcheck source=/dev/null
        . "$profile"
        printf '%s\n' "${!1:-}"
    )
}

run_switch() {
    set +e
    "$test_dir/bin/btcpay-switch" "$@" > "$test_dir/stdout" 2> "$test_dir/stderr"
    status=$?
    set -e
    output="$(<"$test_dir/stdout")"
    error_output="$(<"$test_dir/stderr")"
}

export PATH="$test_dir/bin:$PATH"
export BTCPAY_SWITCH_PROFILE="$profile"
export TEST_BASE_DIRECTORY="$deployment_dir"
export TEST_SETUP_CALLS="$setup_calls_file"
export TEST_SETUP_ENVIRONMENT="$setup_environment_file"
export BTCPAY_IMAGE="caller-only"

run_switch
[ "$status" -eq 0 ]
[[ "$output" == Usage:* ]]

run_switch node
[ "$status" -eq 1 ]
[[ "$error_output" == Usage:* ]]

run_switch ln --help
[ "$status" -eq 0 ]
[[ "$output" == *"clightning|lnd|phoenixd|none"* ]]

write_profile none ' BITCOINCORE.YML ' ' BITCOIN.YML '
write_manifest bitcoin bitcoincore
run_switch node default
[ "$status" -eq 0 ]
[ "$(profile_value BTCPAYGEN_ADDITIONAL_FRAGMENTS)" = "" ]
[ "$(profile_value BTCPAYGEN_EXCLUDE_FRAGMENTS)" = "" ]
[ "$(setup_calls)" -eq 1 ]
[ "$(sort -u "$TEST_SETUP_ENVIRONMENT")" = "saved-image" ]

run_switch node default
[ "$status" -eq 0 ]
[[ "$output" == *"already set to default"* ]]
[ "$(setup_calls)" -eq 1 ]

run_switch node bitcoincore
[ "$status" -eq 0 ]
[ "$(profile_value BTCPAYGEN_ADDITIONAL_FRAGMENTS)" = "bitcoincore" ]
[ "$(profile_value BTCPAYGEN_EXCLUDE_FRAGMENTS)" = "bitcoin" ]
[ "$(setup_calls)" -eq 2 ]

write_profile none
write_manifest bitcoin
run_switch ln clightning
[ "$status" -eq 0 ]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "clightning" ]
[ "$(setup_calls)" -eq 3 ]

write_manifest bitcoin bitcoin-clightning
run_switch ln clightning
[ "$status" -eq 0 ]
[[ "$output" == *"already set to clightning"* ]]
[ "$(setup_calls)" -eq 3 ]

run_switch ln lnd
[ "$status" -eq 1 ]
[[ "$error_output" == *"rerun with --yes"* ]]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "clightning" ]
[ "$(setup_calls)" -eq 3 ]

run_switch ln --yes lnd
[ "$status" -eq 0 ]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "lnd" ]
[[ "$error_output" == *"does not migrate wallets, channels, or liquidity"* ]]
[ "$(setup_calls)" -eq 4 ]

write_profile lnd opt-add-lightning-terminal
write_manifest bitcoin bitcoin-lnd opt-add-lightning-terminal
run_switch ln --yes clightning
[ "$status" -eq 1 ]
[[ "$error_output" == *"Remove LND-dependent add-ons"* ]]
[ "$(setup_calls)" -eq 4 ]

write_profile lnd bitcoin-lnd
write_manifest bitcoin bitcoin-lnd
run_switch ln --yes clightning
[ "$status" -eq 1 ]
[[ "$error_output" == *"Remove direct Lightning fragment overrides"* ]]
[ "$(setup_calls)" -eq 4 ]

write_profile lnd opt-lnd-autopilot
write_manifest bitcoin bitcoin-lnd opt-lnd-autopilot
run_switch ln --yes clightning
[ "$status" -eq 0 ]
[ "$(profile_value BTCPAYGEN_ADDITIONAL_FRAGMENTS)" = "opt-lnd-autopilot" ]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "clightning" ]
[ "$(setup_calls)" -eq 5 ]

write_profile none "" "" btc grs
write_manifest bitcoin groestlcoin
run_switch ln phoenixd
[ "$status" -eq 0 ]
[[ "$error_output" == *"phoenixd is not supported for: grs"* ]]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "phoenixd" ]
[ "$(setup_calls)" -eq 6 ]

write_profile none "" "" btc ltc
write_manifest bitcoin litecoin
run_switch ln lnd
[ "$status" -eq 0 ]
[[ "$error_output" == *"lnd is not supported for: ltc"* ]]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "lnd" ]
[ "$(setup_calls)" -eq 7 ]

write_profile none "" "" ltc
write_manifest litecoin
run_switch ln lnd
[ "$status" -eq 1 ]
[[ "$error_output" == *"not supported by any selected cryptocurrency"* ]]
[ "$(setup_calls)" -eq 7 ]

write_profile broken
write_manifest bitcoin
run_switch ln lnd
[ "$status" -eq 0 ]
[[ "$error_output" == *"replacing invalid saved BTCPAYGEN_LIGHTNING value"* ]]
[ "$(profile_value BTCPAYGEN_LIGHTNING)" = "lnd" ]
[ "$(setup_calls)" -eq 8 ]

write_profile none
write_manifest bitcoin
cp "$profile" "$test_dir/profile-before"
export TEST_SETUP_FAIL=true
run_switch ln clightning
[ "$status" -eq 1 ]
[[ "$error_output" == *"previous deployment profile restored"* ]]
cmp -s "$profile" "$test_dir/profile-before"
[ "$(setup_calls)" -eq 9 ]
unset TEST_SETUP_FAIL

write_id 1000
run_switch ln clightning
[ "$status" -eq 1 ]
[[ "$error_output" == *"must be run as root"* ]]
[ "$(setup_calls)" -eq 9 ]

run_switch node default --yes
[ "$status" -eq 1 ]
[[ "$error_output" == Usage:* ]]

printf 'btcpay-switch tests passed\n'
