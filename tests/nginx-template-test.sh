#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
test_id="btcpay-nginx-template-$$"
network="$test_id"
backend="$test_id-backend"
local_backend="$test_id-local"
nonlocal_backend="$test_id-nonlocal"
nohttps_backend="$test_id-nohttps"
generator="$test_id-generator"
nginx_image="$("$repo_dir/tests/docker-fragment-image.sh" nginx)"
docker_gen_image="$("$repo_dir/tests/docker-fragment-image.sh" nginx-gen)"

cleanup() {
    docker rm -f "$generator" "$backend" "$local_backend" "$nonlocal_backend" "$nohttps_backend" >/dev/null 2>&1 || true
    docker network rm "$network" >/dev/null 2>&1 || true
    rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/certs" "$test_dir/conf" "$test_dir/vhost" "$test_dir/html"
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -subj '/CN=default' \
    -keyout "$test_dir/certs/default.key" \
    -out "$test_dir/certs/default.crt" >/dev/null 2>&1
docker network create "$network" >/dev/null

docker run -d --name "$backend" --network "$network" --expose 80 \
    -e VIRTUAL_HOST=template.test \
    -e VIRTUAL_HOST_NAME=template_test \
    "$nginx_image" >/dev/null

docker run -d --name "$local_backend" --network "$network" --expose 80 \
    -e VIRTUAL_HOST=development.local \
    -e VIRTUAL_HOST_NAME=local_test \
    "$nginx_image" >/dev/null

docker run -d --name "$nonlocal_backend" --network "$network" --expose 80 \
    -e VIRTUAL_HOST=notlocal \
    -e VIRTUAL_HOST_NAME=nonlocal_test \
    "$nginx_image" >/dev/null

docker run -d --name "$nohttps_backend" --network "$network" --expose 80 \
    -e VIRTUAL_HOST=disabled.local \
    -e VIRTUAL_HOST_NAME=nohttps_test \
    -e HTTPS_METHOD=nohttps \
    "$nginx_image" >/dev/null

docker run --rm --name "$generator" --network "$network" \
    -e DEFAULT_HOST=none \
    -e 'RESOLVERS=127.0.0.11 valid=30s ipv6=off' \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    -v "$repo_dir/nginx:/etc/docker-gen/templates:ro" \
    -v "$test_dir/certs:/etc/nginx/certs:ro" \
    -v "$test_dir/conf:/etc/nginx/conf.d" \
    -v "$test_dir/vhost:/etc/nginx/vhost.d" \
    -v "$test_dir/html:/usr/share/nginx/html" \
    --entrypoint /usr/local/bin/docker-gen \
    "$docker_gen_image" \
    /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf

backend_ip="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$network\").IPAddress}}" "$backend")"
grep -Fq 'upstream template_test {' "$test_dir/conf/default.conf"
grep -Fq "server $backend_ip:80;" "$test_dir/conf/default.conf"
grep -Fq 'server_name template.test;' "$test_dir/conf/default.conf"
grep -Fq 'proxy_pass http://template_test;' "$test_dir/conf/default.conf"

# Only actual .local hosts use the development certificate for HTTPS. An
# uncertified non-local host, and a .local host opting out of HTTPS, reject SNI.
test "$(grep -Fc 'proxy_pass http://local_test;' "$test_dir/conf/default.conf")" -eq 2
test "$(grep -Fc 'proxy_pass http://nonlocal_test;' "$test_dir/conf/default.conf")" -eq 1
test "$(grep -Fc 'proxy_pass http://nohttps_test;' "$test_dir/conf/default.conf")" -eq 1
test "$(grep -Fc 'ssl_reject_handshake on;' "$test_dir/conf/default.conf")" -eq 3
test "$(grep -Fc 'ssl_certificate /etc/nginx/certs/default.crt;' "$test_dir/conf/default.conf")" -eq 2
if grep -Fq 'return 500;' "$test_dir/conf/default.conf"; then
    printf 'Uncertified TLS hosts must reject the handshake, not return HTTP 500\n' >&2
    exit 1
fi

docker run --rm \
    -v "$test_dir/certs:/etc/nginx/certs:ro" \
    -v "$test_dir/conf:/etc/nginx/conf.d:ro" \
    -v "$test_dir/vhost:/etc/nginx/vhost.d:ro" \
    -v "$test_dir/html:/usr/share/nginx/html:ro" \
    -v "$repo_dir/nginx:/etc/nginx/btcpay-routes:ro" \
    "$nginx_image" nginx -t

printf 'Nginx template tests passed\n'
