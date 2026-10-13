#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Generated"

jq -n '{secrets:["../secrets/test", "../secrets/nested/second"]}' > "$test_dir/Generated/manifest.json"
"$repo_dir/generate-secrets.sh" "$test_dir/Generated/manifest.json"

[[ "$(< "$test_dir/secrets/test")" =~ ^[a-zA-Z0-9]{64}$ ]]
[[ "$(< "$test_dir/secrets/nested/second")" =~ ^[a-zA-Z0-9]{64}$ ]]
[[ "$(stat -c %a "$test_dir/secrets")" == "700" ]]
[[ "$(stat -c %a "$test_dir/secrets/nested")" == "700" ]]
[[ "$(stat -c %a "$test_dir/secrets/test")" == "644" ]]

original="$(< "$test_dir/secrets/test")"
"$repo_dir/generate-secrets.sh" "$test_dir/Generated/manifest.json"
[[ "$(< "$test_dir/secrets/test")" == "$original" ]]

jq -n '{requiredRoutes:[],optionalRoutes:[],fragments:[]}' > "$test_dir/Generated/manifest.json"
"$repo_dir/generate-secrets.sh" "$test_dir/Generated/manifest.json"

jq -n '{secrets:["../../outside"]}' > "$test_dir/Generated/manifest.json"
if "$repo_dir/generate-secrets.sh" "$test_dir/Generated/manifest.json" 2>/dev/null; then
    printf 'Paths outside the secrets directory must be rejected\n' >&2
    exit 1
fi
[[ ! -e "$test_dir/../outside" ]]

rm -rf "$test_dir/secrets"
ln -s "$test_dir/elsewhere" "$test_dir/secrets"
jq -n '{secrets:["../secrets/test"]}' > "$test_dir/Generated/manifest.json"
if "$repo_dir/generate-secrets.sh" "$test_dir/Generated/manifest.json" 2>/dev/null; then
    printf 'A symlinked secrets directory must be rejected\n' >&2
    exit 1
fi

rm "$test_dir/secrets"
mkdir "$test_dir/secrets" "$test_dir/elsewhere"
ln -s "$test_dir/elsewhere" "$test_dir/secrets/nested"
jq -n '{secrets:["../secrets/nested/test"]}' > "$test_dir/Generated/manifest.json"
if "$repo_dir/generate-secrets.sh" "$test_dir/Generated/manifest.json" 2>/dev/null; then
    printf 'A symlinked secret directory must be rejected\n' >&2
    exit 1
fi

printf 'Secret generation tests passed\n'
