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
    (.fragments | index("nginx-https") == null)
' "$test_dir/Generated/manifest.json" >/dev/null

if grep -q "letsencrypt-nginx-proxy-companion" \
    "$test_dir/Generated/docker-compose.fragment-exclusion-test.yml"; then
    printf 'Excluded nginx-https services were generated\n' >&2
    exit 1
fi

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
