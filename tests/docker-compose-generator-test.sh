#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

generator_dir="$test_dir/docker-compose-generator"
mkdir -p "$generator_dir" "$test_dir/Generated"
cp -a \
    "$repo_dir/docker-compose-generator/src" \
    "$repo_dir/docker-compose-generator/docker-fragments" \
    "$repo_dir/docker-compose-generator/crypto-definitions.json" \
    "$generator_dir/"
rm -rf "$generator_dir/src/bin" "$generator_dir/src/obj"

(
    cd "$generator_dir"
    BTCPAYGEN_REVERSEPROXY="nginx" \
    BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-add-cloudflared" \
    BTCPAYGEN_SUBNAME="fragment-exclusion-test" \
    dotnet run \
        --project src/docker-compose-generator.csproj \
        --configuration Release \
        --no-launch-profile \
        -p:TargetFrameworkOverride=net8.0
)

jq -e '
    (.fragments | index("opt-add-cloudflared") != null) and
    (.fragments | index("nginx") != null) and
    (.fragments | index("btcpay-host") != null) and
    (.fragments | index("nginx-https") == null)
' "$test_dir/Generated/manifest.json" >/dev/null
grep -q 'BTCPAY_BTCPAYHOSTENABLED' \
    "$test_dir/Generated/docker-compose.fragment-exclusion-test.yml"
grep -q 'btcpay_host_id_ed25519' \
    "$test_dir/Generated/docker-compose.fragment-exclusion-test.yml"

if grep -q "letsencrypt-nginx-proxy-companion" \
    "$test_dir/Generated/docker-compose.fragment-exclusion-test.yml"; then
    printf 'Excluded nginx-https services were generated\n' >&2
    exit 1
fi

# Secrets must not be interpolated into host-visible process arguments.
cloudflared_compose="$test_dir/Generated/docker-compose.fragment-exclusion-test.yml"
if grep -q -- '--token\|command:.*CLOUDFLARE_TUNNEL_TOKEN' "$cloudflared_compose"; then
    printf 'The Cloudflare Tunnel token was generated as a command argument\n' >&2
    exit 1
fi
grep -Fq 'TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN}' "$cloudflared_compose"

(
    cd "$generator_dir"
    BTCPAYGEN_CRYPTO1="dcr" \
    BTCPAYGEN_REVERSEPROXY="nginx" \
    BTCPAYGEN_SUBNAME="decred-test" \
    dotnet run \
        --no-build \
        --project src/docker-compose-generator.csproj \
        --configuration Release \
        --no-launch-profile \
        -p:TargetFrameworkOverride=net8.0
)

jq -e '(.fragments | index("decred") != null)' \
    "$test_dir/Generated/manifest.json" >/dev/null
decred_compose="$test_dir/Generated/docker-compose.decred-test.yml"
if grep -q -- '--pass=' "$decred_compose"; then
    printf 'The Decred wallet passphrase was generated as a command argument\n' >&2
    exit 1
fi
grep -Fq 'BTCPAY_DCR_WALLET_PASSPHRASE: ${BTCPAY_DCR_WALLET_PASSPHRASE}' "$decred_compose"
grep -Fq -- '--configfile=' "$decred_compose"
# Compose must leave the runtime shell references intact, not insert the secret.
BTCPAY_DCR_WALLET_PASSPHRASE='compose-test-secret' docker compose \
    -f "$decred_compose" config --format json > "$test_dir/decred.json"
jq -e '
    .services.dcrwallet |
    .environment.BTCPAY_DCR_WALLET_PASSPHRASE == "compose-test-secret" and
    ((.command + .entrypoint | join(" ")) | contains("compose-test-secret") | not) and
    (.entrypoint[2] | contains("$BTCPAY_DCR_WALLET_PASSPHRASE"))
' "$test_dir/decred.json" >/dev/null

# Exercise the actual generated wrapper without touching a wallet or host /run.
wallet_wrapper="$(jq -r '.services.dcrwallet.entrypoint[2]' "$test_dir/decred.json")"
# `compose config` retains escaped dollars for another Compose invocation;
# container creation resolves each $$ to a literal $.
wallet_wrapper="${wallet_wrapper//\$\$/\$}"
wallet_wrapper="${wallet_wrapper//\/run\/dcrwallet.conf/$test_dir/runtime.conf}"
wallet_wrapper="${wallet_wrapper//\/root\/.dcrwallet\/dcrwallet.conf/$test_dir/existing.conf}"
printf '%s\n' '[Application Options]' 'debuglevel=warn' > "$test_dir/existing.conf"
for passphrase in '' 'ordinary' ' leading and trailing ' '"quoted"' 'back\slash' \
    '$dollar; `not a command`' $'line one\nline two\n' $'tabs\tand\rreturns'; do
    BTCPAY_DCR_WALLET_PASSPHRASE="$passphrase" \
        sh -ec "$wallet_wrapper" -- sh -c '
            test "${BTCPAY_DCR_WALLET_PASSPHRASE+x}" != x
            printf "%s\n" "$@"
        ' -- > "$test_dir/wallet-args"
    grep -Fxq -- "--configfile=$test_dir/runtime.conf" "$test_dir/wallet-args"
    [ "$(stat -c %a "$test_dir/runtime.conf")" = 600 ]
    grep -Fxq 'debuglevel=warn' "$test_dir/runtime.conf"
    # The wrapper emits the JSON-compatible subset of Go string quoting.
    tail -n 1 "$test_dir/runtime.conf" | \
        jq -R -e --arg expected "$passphrase" 'ltrimstr("pass=") | fromjson == $expected' >/dev/null
done
rm "$test_dir/existing.conf"
BTCPAY_DCR_WALLET_PASSPHRASE="" sh -ec "$wallet_wrapper" -- true
grep -Fxq 'pass=""' "$test_dir/runtime.conf"

(
    cd "$generator_dir"
    BTCPAYGEN_REVERSEPROXY="nginx" \
    BTCPAYGEN_EXCLUDE_FRAGMENTS="btcpay-host" \
    BTCPAYGEN_SUBNAME="recommended-exclusion-test" \
    dotnet run \
        --no-build \
        --project src/docker-compose-generator.csproj \
        --configuration Release \
        --no-launch-profile \
        -p:TargetFrameworkOverride=net8.0
)

jq -e '(.fragments | index("btcpay-host") == null)' \
    "$test_dir/Generated/manifest.json" >/dev/null
if grep -q 'BTCPAY_BTCPAYHOSTENABLED\|btcpay_host_id_ed25519' \
    "$test_dir/Generated/docker-compose.recommended-exclusion-test.yml"; then
    printf 'Excluded btcpay-host configuration was generated\n' >&2
    exit 1
fi

(
    cd "$generator_dir"
    BTCPAYGEN_CRYPTO1="btc" \
    BTCPAYGEN_REVERSEPROXY="nginx" \
    BTCPAYGEN_LIGHTNING="clightning" \
    BTCPAYGEN_ADDITIONAL_FRAGMENTS="" \
    BTCPAYGEN_SUBNAME="lightning-default-test" \
    dotnet run \
        --no-build \
        --project src/docker-compose-generator.csproj \
        --configuration Release \
        --no-launch-profile \
        -p:TargetFrameworkOverride=net8.0
)

jq -e '
    .requiredRoutes == ["rtl"] and
    .secrets == [] and
    (.fragments | index("opt-add-tor") == null)
' "$test_dir/Generated/manifest.json" >/dev/null
grep -q 'bitcoin_rtl' \
    "$test_dir/Generated/docker-compose.lightning-default-test.yml"
# HTTP-01 challenges are generated by the template, not a shared legacy vhost
# volume. Keep certificates and challenge files shared with the companion.
if grep -q 'nginx_vhost\|/etc/nginx/vhost.d' \
    "$test_dir/Generated/docker-compose.lightning-default-test.yml"; then
    printf 'Obsolete nginx vhost volume was generated\n' >&2
    exit 1
fi
grep -q 'nginx_certs:/etc/nginx/certs:rw' \
    "$test_dir/Generated/docker-compose.lightning-default-test.yml"
grep -q 'nginx_html:/usr/share/nginx/html' \
    "$test_dir/Generated/docker-compose.lightning-default-test.yml"
if grep -q 'generated_tor_\|container_name: tor' \
    "$test_dir/Generated/docker-compose.lightning-default-test.yml"; then
    printf 'Tor configuration was generated by default\n' >&2
    exit 1
fi

(
    cd "$generator_dir"
    BTCPAYGEN_CRYPTO1="btc" \
    BTCPAYGEN_REVERSEPROXY="nginx" \
    BTCPAYGEN_LIGHTNING="clightning" \
    BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-add-tor" \
    BTCPAYGEN_SUBNAME="clightning-tor-test" \
    dotnet run \
        --no-build \
        --project src/docker-compose-generator.csproj \
        --configuration Release \
        --no-launch-profile \
        -p:TargetFrameworkOverride=net8.0
)

jq -e '
    .requiredRoutes == ["rtl"] and
    .secrets == ["../secrets/tor_password"] and
    (.fragments | index("opt-add-tor") != null)
' "$test_dir/Generated/manifest.json" >/dev/null
grep -q 'LN_IMPLEMENTATION: CLN' \
    "$test_dir/Generated/docker-compose.clightning-tor-test.yml"
docker compose \
    -f "$test_dir/Generated/docker-compose.clightning-tor-test.yml" \
    config --quiet

set +e
proxy_conflict_output="$({
    cd "$generator_dir" || exit 1
    BTCPAYGEN_REVERSEPROXY="none" \
    BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-add-cloudflared" \
    BTCPAYGEN_SUBNAME="fragment-requirement-test" \
    dotnet run \
        --no-build \
        --project src/docker-compose-generator.csproj \
        --configuration Release \
        --no-launch-profile \
        -p:TargetFrameworkOverride=net8.0
} 2>&1)"
proxy_conflict_status=$?
set -e

[ "$proxy_conflict_status" -eq 1 ]
[[ "$proxy_conflict_output" == *"group 'proxy'"* ]]

printf 'Docker Compose generator tests passed\n'
