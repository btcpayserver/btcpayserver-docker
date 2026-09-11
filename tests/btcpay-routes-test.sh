#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/config"
ln -s "$repo_dir" "$test_dir/btcpayserver-docker"
ln -s "$repo_dir/btcpay-routes" "$test_dir/bin/btcpay-routes"
ln -s "$repo_dir/nginx/routes" "$test_dir/config/routes"

cat > "$test_dir/bin/docker" <<'EOF'
#!/bin/bash
case "$1" in
    inspect)
        printf '%s\n' "${DOCKER_RUNNING:-true}"
        ;;
    exec)
        if [ "${NGINX_TEST_FAIL:-false}" = "true" ]; then
            printf '%s\n' "nginx: configuration test failed" >&2
            exit 1
        fi
        ;;
    kill)
        if [ "${HUP_FAIL:-false}" = "true" ]; then
            exit 1
        fi
        ;;
    *)
        exit 1
        ;;
esac
EOF

chmod +x "$test_dir/bin/docker"

export PATH="$test_dir/bin:$PATH"
export BTCPAY_ROUTES_SKIP_PROFILE=true
export BTCPAY_ROUTES_CONFIG_DIR="$test_dir/config"
export BTCPAY_ROUTES_MANIFEST="$test_dir/manifest.json"
export BTCPAY_BASE_DIRECTORY="$test_dir"
export BTCPAYGEN_REVERSEPROXY=nginx

write_manifest() {
    jq -n --argjson required "$1" --argjson optional "$2" \
        '{requiredRoutes:$required,optionalRoutes:$optional,fragments:["test"]}' > "$BTCPAY_ROUTES_MANIFEST"
}

write_manifest '["mempool"]' '["thunderhub"]'

run_routes() {
    set +e
    output="$("$test_dir/bin/btcpay-routes" "$@")"
    status=$?
    set -e
}

assert_json_state() {
    local optional="$1"
    local enabled="$2"
    jq -e --argjson optional "$optional" --argjson enabled "$enabled" \
        '.optionalRoutes == $optional and .enabledRoutes == $enabled and keys == ["enabledRoutes", "optionalRoutes"]' \
        <<< "$output" >/dev/null
}

run_routes
[ "$status" -eq 0 ]
[[ "$output" == Usage:* ]]
[[ "$output" == *"btcpay-routes <command> [routes...]"* ]]
if jq -e . <<< "$output" >/dev/null 2>&1; then
    printf 'Help output must be plain text\n' >&2
    exit 1
fi

run_routes help
[ "$status" -eq 0 ]
[[ "$output" == Usage:* ]]

run_routes sync
[ "$status" -eq 0 ]
assert_json_state '["thunderhub"]' '["mempool"]'
[ -f "$test_dir/config/enabled-routes/mempool.conf" ]
[ -L "$test_dir/config/enabled-routes/mempool.conf" ]
[ "$(readlink "$test_dir/config/enabled-routes/mempool.conf")" = "../routes/mempool.conf" ]

run_routes add thunderhub
[ "$status" -eq 0 ]
assert_json_state '["thunderhub"]' '["mempool","thunderhub"]'

run_routes sync
[ "$status" -eq 0 ]
assert_json_state '["thunderhub"]' '["mempool","thunderhub"]'

run_routes remove thunderhub missing-route
[ "$status" -eq 1 ]
jq -e 'keys == ["error"] and .error == "Unknown route: missing-route"' <<< "$output" >/dev/null
[ -L "$test_dir/config/enabled-routes/thunderhub.conf" ]

run_routes remove mempool
[ "$status" -eq 1 ]
jq -e 'keys == ["error"] and .error == "Route is required and cannot be changed: mempool"' <<< "$output" >/dev/null
[ -f "$test_dir/config/enabled-routes/mempool.conf" ]

run_routes remove thunderhub
[ "$status" -eq 0 ]
assert_json_state '["thunderhub"]' '["mempool"]'

write_manifest '["mempool"]' '[]'
run_routes sync
[ "$status" -eq 0 ]
assert_json_state '[]' '["mempool"]'
[ ! -L "$test_dir/config/enabled-routes/thunderhub.conf" ]

write_manifest '["mempool"]' '["thunderhub"]'
export NGINX_TEST_FAIL=true
run_routes add thunderhub
[ "$status" -eq 1 ]
jq -e 'keys == ["error"] and (.error | startswith("nginx validation failed:"))' <<< "$output" >/dev/null
[ ! -L "$test_dir/config/enabled-routes/thunderhub.conf" ]
unset NGINX_TEST_FAIL

export DOCKER_RUNNING=false
run_routes add thunderhub
[ "$status" -eq 1 ]
jq -e 'keys == ["error"] and (.error | startswith("nginx is not running;"))' <<< "$output" >/dev/null
[ -L "$test_dir/config/enabled-routes/thunderhub.conf" ]
unset DOCKER_RUNNING

export HUP_FAIL=true
run_routes remove thunderhub
[ "$status" -eq 1 ]
jq -e 'keys == ["error"] and (.error | startswith("nginx configuration is valid,"))' <<< "$output" >/dev/null
[ -L "$test_dir/config/enabled-routes/thunderhub.conf" ]
unset HUP_FAIL

write_manifest '["rtl"]' '["lnd-grpc","lnd-rest"]'
run_routes sync
[ "$status" -eq 0 ]
assert_json_state '["lnd-grpc","lnd-rest"]' '["rtl"]'

run_routes add lnd-rest
[ "$status" -eq 0 ]
assert_json_state '["lnd-grpc","lnd-rest"]' '["lnd-rest","rtl"]'

run_routes add lnd-grpc
[ "$status" -eq 0 ]
assert_json_state '["lnd-grpc","lnd-rest"]' '["lnd-grpc","lnd-rest","rtl"]'

write_manifest '["rtl"]' '["clightning-rest"]'
run_routes sync
[ "$status" -eq 0 ]
assert_json_state '["clightning-rest"]' '["rtl"]'

run_routes add clightning-rest
[ "$status" -eq 0 ]
assert_json_state '["clightning-rest"]' '["clightning-rest","rtl"]'

export BTCPAYGEN_REVERSEPROXY=none
run_routes show
[ "$status" -eq 1 ]
jq -e 'keys == ["error"] and .error == "BTCPAYGEN_REVERSEPROXY must be nginx"' <<< "$output" >/dev/null

printf 'btcpay-routes tests passed\n'
