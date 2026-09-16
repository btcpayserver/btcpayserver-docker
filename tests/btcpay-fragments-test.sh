#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

deployment_dir="$test_dir/deployment"
test_repo="$deployment_dir/btcpayserver-docker"
fragment_dir="$test_repo/docker-compose-generator/docker-fragments"
profile="$test_dir/btcpay-env.sh"
mkdir -p "$test_dir/bin" "$fragment_dir"
ln -s "$repo_dir/btcpay-fragments" "$test_dir/bin/btcpay-fragments"

touch \
    "$fragment_dir/alpha.yml" \
    "$fragment_dir/beta.yml" \
    "$fragment_dir/gamma.yml" \
    "$fragment_dir/Local.Custom.yml" \
    "$fragment_dir/bad name.yml"

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
printf '%s\n' "${TEST_OVERRIDE:-unset}" >> "$TEST_SETUP_OVERRIDES"
{
    printf 'export BTCPAY_BASE_DIRECTORY=%q\n' "$TEST_BASE_DIRECTORY"
    printf 'export BTCPAYGEN_ADDITIONAL_FRAGMENTS=%q\n' "$BTCPAYGEN_ADDITIONAL_FRAGMENTS"
    printf 'export BTCPAYGEN_EXCLUDE_FRAGMENTS=%q\n' "$BTCPAYGEN_EXCLUDE_FRAGMENTS"
    printf 'export TEST_OVERRIDE=%q\n' "profile"
} > "$BTCPAY_FRAGMENTS_PROFILE"
if [ "${TEST_SETUP_FAIL:-false}" = "true" ]; then
    printf 'setup failed\n' >&2
    return 1
fi
return 0
EOF
chmod +x "$test_repo/btcpay-setup.sh"

write_profile() {
    {
        printf 'export BTCPAY_BASE_DIRECTORY=%q\n' "$deployment_dir"
        printf 'export BTCPAYGEN_ADDITIONAL_FRAGMENTS=%q\n' "$1"
        printf 'export BTCPAYGEN_EXCLUDE_FRAGMENTS=%q\n' "$2"
        printf 'export TEST_OVERRIDE=%q\n' "profile"
    } > "$profile"
}

write_profile ' stale.yml ; beta ; beta ' 'nginx-https;legacy-missing'

export PATH="$test_dir/bin:$PATH"
export BTCPAY_FRAGMENTS_PROFILE="$profile"
export TEST_BASE_DIRECTORY="$deployment_dir"
export TEST_SETUP_OVERRIDES="$test_dir/setup-overrides"
export TEST_OVERRIDE="caller"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="parent-stale-additional"
export BTCPAYGEN_EXCLUDE_FRAGMENTS="parent-stale-excluded"

run_fragments() {
    set +e
    "$test_dir/bin/btcpay-fragments" "$@" > "$test_dir/stdout" 2> "$test_dir/stderr"
    status=$?
    set -e
    output="$(<"$test_dir/stdout")"
    error_output="$(<"$test_dir/stderr")"
}

assert_state() {
    local additional="$1"
    local excluded="$2"
    local effective="${3:-[]}"
    jq -e \
        --argjson additional "$additional" \
        --argjson excluded "$excluded" \
        --argjson effective "$effective" '
        keys == ["additionalFragments", "availableFragments", "effectiveFragments", "excludedFragments"] and
        .additionalFragments == $additional and
        .excludedFragments == $excluded and
        .effectiveFragments == $effective and
        .availableFragments == ["Local.Custom", "alpha", "bad name", "beta", "gamma"]
    ' <<< "$output" >/dev/null
}

setup_calls() {
    if [ -f "$TEST_SETUP_OVERRIDES" ]; then
        wc -l < "$TEST_SETUP_OVERRIDES"
    else
        printf '0\n'
    fi
}

run_fragments
[ "$status" -eq 0 ]
[[ "$output" == Usage:* ]]
[[ "$output" == *"btcpay-fragments <command> [fragments...]"* ]]

run_fragments --help
[ "$status" -eq 0 ]
[[ "$output" == Usage:* ]]

run_fragments show
[ "$status" -eq 0 ]
assert_state '["beta","stale"]' '["legacy-missing","nginx-https"]'
[ "$(setup_calls)" -eq 0 ]

mkdir -p "$test_repo/Generated"
jq -n '{fragments:["nginx", "alpha"]}' > "$test_repo/Generated/manifest.json"
run_fragments show
[ "$status" -eq 0 ]
assert_state '["beta","stale"]' '["legacy-missing","nginx-https"]' '["alpha","nginx"]'

printf '{invalid\n' > "$test_repo/Generated/manifest.json"
run_fragments show
[ "$status" -eq 1 ]
jq -e '.error | startswith("Generated manifest contains invalid fragment metadata:")' <<< "$output" >/dev/null
rm -f "$test_repo/Generated/manifest.json"

run_fragments show unexpected
[ "$status" -eq 1 ]
jq -e '.error == "show does not accept arguments"' <<< "$output" >/dev/null

run_fragments add beta
[ "$status" -eq 0 ]
assert_state '["beta","stale"]' '["legacy-missing","nginx-https"]'
[ "$(setup_calls)" -eq 0 ]

write_id 1000
run_fragments add beta
[ "$status" -eq 1 ]
jq -e '.error == "Fragment changes must be run as root"' <<< "$output" >/dev/null
[ "$(setup_calls)" -eq 0 ]
write_id 0

run_fragments add ' ALPHA.YML '
[ "$status" -eq 0 ]
assert_state '["alpha","beta","stale"]' '["legacy-missing","nginx-https"]'
[ "$(setup_calls)" -eq 1 ]
[ "$(<"$TEST_SETUP_OVERRIDES")" = "caller" ]
[[ "$error_output" == *"setup invoked"* ]]

profile_before="$test_dir/profile-before"
cp "$profile" "$profile_before"
run_fragments add missing 'bad;name' gamma
[ "$status" -eq 1 ]
jq -e '.error == "Unknown or invalid fragments: bad;name, missing"' <<< "$output" >/dev/null
cmp -s "$profile" "$profile_before"
[ "$(setup_calls)" -eq 1 ]

run_fragments add Local.Custom
[ "$status" -eq 1 ]
jq -e '.error == "Unknown or invalid fragments: local.custom"' <<< "$output" >/dev/null
[ "$(setup_calls)" -eq 1 ]

run_fragments add btcpay-host
[ "$status" -eq 1 ]
jq -e '.error == "Unknown or invalid fragments: btcpay-host"' <<< "$output" >/dev/null
[ "$(setup_calls)" -eq 1 ]

run_fragments exclude beta
[ "$status" -eq 0 ]
assert_state '["alpha","stale"]' '["beta","legacy-missing","nginx-https"]'
[ "$(setup_calls)" -eq 2 ]

run_fragments add beta
[ "$status" -eq 0 ]
assert_state '["alpha","beta","stale"]' '["legacy-missing","nginx-https"]'
[ "$(setup_calls)" -eq 3 ]

run_fragments unexclude legacy-missing
[ "$status" -eq 0 ]
assert_state '["alpha","beta","stale"]' '["nginx-https"]'
[ "$(setup_calls)" -eq 4 ]

run_fragments remove stale
[ "$status" -eq 0 ]
assert_state '["alpha","beta"]' '["nginx-https"]'
[ "$(setup_calls)" -eq 5 ]

run_fragments remove absent-stale
[ "$status" -eq 1 ]
jq -e '.error == "Unknown or invalid fragments: absent-stale"' <<< "$output" >/dev/null
[ "$(setup_calls)" -eq 5 ]

run_fragments unexclude absent-stale
[ "$status" -eq 1 ]
jq -e '.error == "Unknown or invalid fragments: absent-stale"' <<< "$output" >/dev/null
[ "$(setup_calls)" -eq 5 ]

write_profile 'alpha;removed-custom' 'nginx-https;removed-exclusion'
run_fragments remove removed-custom
[ "$status" -eq 0 ]
assert_state '["alpha"]' '["nginx-https","removed-exclusion"]'
[ "$(setup_calls)" -eq 6 ]

run_fragments unexclude removed-exclusion
[ "$status" -eq 0 ]
assert_state '["alpha"]' '["nginx-https"]'
[ "$(setup_calls)" -eq 7 ]

cp "$profile" "$profile_before"
cat > "$test_dir/bin/cp" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$test_dir/bin/cp"
run_fragments add gamma
[ "$status" -eq 1 ]
jq -e '.error == "Failed to back up deployment profile"' <<< "$output" >/dev/null
cmp -s "$profile" "$profile_before"
[ "$(setup_calls)" -eq 7 ]
rm "$test_dir/bin/cp"

export TEST_SETUP_FAIL=true
run_fragments add gamma
[ "$status" -eq 1 ]
jq -e '.error == "Failed to apply fragment changes; previous deployment profile restored"' <<< "$output" >/dev/null
[[ "$error_output" == *"setup failed"* ]]
cmp -s "$profile" "$profile_before"
[ "$(setup_calls)" -eq 8 ]
unset TEST_SETUP_FAIL

cat > "$test_dir/bin/mv" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$test_dir/bin/mv"
export TEST_SETUP_FAIL=true
run_fragments add gamma
[ "$status" -eq 1 ]
jq -e '.error == "Failed to apply fragment changes; deployment profile could not be restored"' <<< "$output" >/dev/null
backup_path="${error_output##*Profile backup retained for manual recovery: }"
[ -f "$backup_path" ]
cmp -s "$backup_path" "$profile_before"
[ "$(setup_calls)" -eq 9 ]
rm "$test_dir/bin/mv"
/usr/bin/mv -f -- "$backup_path" "$profile"
unset TEST_SETUP_FAIL

run_fragments show
[ "$status" -eq 0 ]
assert_state '["alpha"]' '["nginx-https"]'

missing_profile="$test_dir/missing-profile"
BTCPAY_FRAGMENTS_PROFILE="$missing_profile" run_fragments show
[ "$status" -eq 1 ]
jq -e --arg profile "$missing_profile" '.error == "Saved deployment profile is not readable: \($profile)"' <<< "$output" >/dev/null

run_fragments unknown
[ "$status" -eq 1 ]
jq -e '.error == "Unknown command: unknown"' <<< "$output" >/dev/null

cat > "$test_dir/bin/docker-compose" <<'EOF'
#!/bin/bash
exit "${DOCKER_COMPOSE_STATUS:-0}"
EOF
chmod +x "$test_dir/bin/docker-compose"

# shellcheck disable=SC1091
. "$repo_dir/helpers.sh"
touch "$test_dir/.env" "$test_dir/docker-compose.yml"
BTCPAY_ENV_FILE="$test_dir/.env"
BTCPAY_DOCKER_COMPOSE="$test_dir/docker-compose.yml"
BTCPAYGEN_REVERSEPROXY="none"
export BTCPAY_ENV_FILE BTCPAY_DOCKER_COMPOSE BTCPAYGEN_REVERSEPROXY
export DOCKER_COMPOSE_STATUS=23
if btcpay_up; then
    printf 'btcpay_up must propagate docker-compose failures\n' >&2
    exit 1
fi
if btcpay_pull; then
    printf 'btcpay_pull must propagate docker-compose failures\n' >&2
    exit 1
fi
unset DOCKER_COMPOSE_STATUS

printf 'btcpay-fragments tests passed\n'
