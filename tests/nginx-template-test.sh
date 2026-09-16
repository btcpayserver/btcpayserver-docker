#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
test_id="btcpay-nginx-template-$$"
primary_network="$test_id-primary"
secondary_network="$test_id-secondary"
isolated_network="$test_id-isolated"
explicit_backend="$test_id-explicit"
multi_backend="$test_id-multi"
fallback_backend="$test_id-fallback"
http_backend="$test_id-http"
https_backend="$test_id-https"
local_backend="$test_id-local"
nonlocal_backend="$test_id-nonlocal"
nohttps_backend="$test_id-nohttps"
generator="$test_id-generator"
nginx_image="$("$repo_dir/tests/docker-fragment-image.sh" nginx)"
docker_gen_image="$("$repo_dir/tests/docker-fragment-image.sh" nginx-gen)"

cleanup() {
    docker rm -f "$generator" "$explicit_backend" "$multi_backend" "$fallback_backend" \
        "$http_backend" "$https_backend" "$local_backend" "$nonlocal_backend" \
        "$nohttps_backend" >/dev/null 2>&1 || true
    docker network rm "$primary_network" "$secondary_network" "$isolated_network" >/dev/null 2>&1 || true
    rm -rf "$test_dir"
}
trap cleanup EXIT

upstream_server_count() {
    awk -v upstream="$1" -v server="$2" '
        $0 == "upstream " upstream " {" { in_upstream = 1; next }
        in_upstream && $0 == "}" { exit }
        in_upstream && index($0, server) { count++ }
        END { print count + 0 }
    ' "$test_dir/conf/default.conf"
}

mkdir -p "$test_dir/certs" "$test_dir/conf" "$test_dir/htpasswd" "$test_dir/vhost" "$test_dir/html"
printf 'allow all;\n' > "$test_dir/network_internal.conf"
printf '' > "$test_dir/fastcgi.conf"
printf 'add_header X-Vhost-Default true;\n' > "$test_dir/vhost/default"
printf 'add_header X-Location-Default true;\n' > "$test_dir/vhost/default_location"
printf 'add_header X-Vhost-Secure true;\n' > "$test_dir/vhost/secure.test"
printf 'tester:test\n' > "$test_dir/htpasswd/secure.test"

for cert_name in default secure; do
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
        -subj "/CN=$cert_name.test" \
        -keyout "$test_dir/certs/$cert_name.key" \
        -out "$test_dir/certs/$cert_name.crt" >/dev/null 2>&1
done

docker network create "$primary_network" >/dev/null
docker network create "$secondary_network" >/dev/null
docker network create "$isolated_network" >/dev/null

docker run -d --name "$explicit_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=explicit.test \
    -e VIRTUAL_HOST_NAME=explicit_test \
    -e VIRTUAL_PORT=8080 \
    "$nginx_image" >/dev/null

docker run -d --name "$http_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=http.test \
    -e VIRTUAL_HOST_NAME=btcpay \
    -e HTTPS_METHOD=nohttps \
    "$nginx_image" >/dev/null

docker run -d --name "$https_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=secure.test \
    -e VIRTUAL_HOST_NAME=secure_test \
    -e CERT_NAME=secure \
    -e NETWORK_ACCESS=internal \
    -e VIRTUAL_PROTO=uwsgi \
    -e HSTS=max-age=1234 \
    "$nginx_image" >/dev/null

docker run -d --name "$multi_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=multi.test \
    -e VIRTUAL_HOST_NAME=multi_test \
    "$nginx_image" >/dev/null
docker network connect "$secondary_network" "$multi_backend"

docker run -d --name "$fallback_backend" --network "$isolated_network" --expose 80 \
    -e VIRTUAL_HOST=fallback.test \
    -e VIRTUAL_HOST_NAME=fallback_test \
    "$nginx_image" >/dev/null

docker run -d --name "$local_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=service.local \
    -e VIRTUAL_HOST_NAME=service_local \
    -e NETWORK_ACCESS=internal \
    -e VIRTUAL_PROTO=fastcgi \
    -e VIRTUAL_ROOT=/srv/service \
    "$nginx_image" >/dev/null

docker run -d --name "$nonlocal_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=notlocal \
    -e VIRTUAL_HOST_NAME=nonlocal_test \
    "$nginx_image" >/dev/null

docker run -d --name "$nohttps_backend" --network "$primary_network" --expose 80 \
    -e VIRTUAL_HOST=disabled.local \
    -e VIRTUAL_HOST_NAME=nohttps_test \
    -e HTTPS_METHOD=nohttps \
    "$nginx_image" >/dev/null

docker create --name "$generator" --network "$primary_network" \
    -e DEFAULT_HOST=none \
    -e 'RESOLVERS=127.0.0.11 valid=30s ipv6=off' \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    -v "$repo_dir/nginx:/etc/docker-gen/templates:ro" \
    -v "$test_dir/certs:/etc/nginx/certs:ro" \
    -v "$test_dir/conf:/etc/nginx/conf.d" \
    -v "$test_dir/htpasswd:/etc/nginx/htpasswd:ro" \
    -v "$test_dir/vhost:/etc/nginx/vhost.d" \
    -v "$test_dir/html:/usr/share/nginx/html" \
    --entrypoint /usr/local/bin/docker-gen \
    "$docker_gen_image" \
    /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf >/dev/null
docker network connect "$secondary_network" "$generator"
docker start -a "$generator"

explicit_ip="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$primary_network\").IPAddress}}" "$explicit_backend")"
multi_primary_ip="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$primary_network\").IPAddress}}" "$multi_backend")"
multi_secondary_ip="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$secondary_network\").IPAddress}}" "$multi_backend")"

grep -Fq 'upstream explicit_test {' "$test_dir/conf/default.conf"
grep -Fq "server $explicit_ip:8080;" "$test_dir/conf/default.conf"
if grep -Fq "server $explicit_ip:80;" "$test_dir/conf/default.conf"; then
    printf 'VIRTUAL_PORT was ignored for a single exposed port\n' >&2
    exit 1
fi

grep -Fq 'upstream multi_test {' "$test_dir/conf/default.conf"
multi_servers="$(upstream_server_count multi_test "server $multi_primary_ip:80;")"
multi_servers=$((multi_servers + $(upstream_server_count multi_test "server $multi_secondary_ip:80;")))
if [[ "$multi_servers" -ne 1 ]]; then
    printf 'Expected one server for a backend on two shared networks, got %s\n' "$multi_servers" >&2
    exit 1
fi

grep -Fq 'upstream fallback_test {' "$test_dir/conf/default.conf"
if [[ "$(upstream_server_count fallback_test 'server 127.0.0.1 down;')" -ne 1 ]]; then
    printf 'Expected exactly one fallback server for the unreachable backend\n' >&2
    exit 1
fi

grep -Fq 'server_name explicit.test;' "$test_dir/conf/default.conf"
grep -Fq 'proxy_pass http://explicit_test;' "$test_dir/conf/default.conf"

# Only actual .local hosts use the development certificate for HTTPS. An
# uncertified non-local host, and a .local host opting out of HTTPS, reject SNI.
test "$(grep -Fc 'fastcgi_pass service_local;' "$test_dir/conf/default.conf")" -eq 2
test "$(grep -Fc 'proxy_pass http://nonlocal_test;' "$test_dir/conf/default.conf")" -eq 1
test "$(grep -Fc 'proxy_pass http://nohttps_test;' "$test_dir/conf/default.conf")" -eq 1
test "$(grep -Fc 'ssl_reject_handshake on;' "$test_dir/conf/default.conf")" -eq 6
test "$(grep -Fc 'ssl_certificate /etc/nginx/certs/default.crt;' "$test_dir/conf/default.conf")" -eq 2
if grep -Fq 'return 500;' "$test_dir/conf/default.conf"; then
    printf 'Uncertified TLS hosts must reject the handshake, not return HTTP 500\n' >&2
    exit 1
fi

http_backend_ip="$(docker inspect --format "{{(index .NetworkSettings.Networks \"$primary_network\").IPAddress}}" "$http_backend")"
grep -Fq 'upstream btcpay {' "$test_dir/conf/default.conf"
grep -Fq "server $http_backend_ip:80;" "$test_dir/conf/default.conf"
grep -Fq 'server_name http.test;' "$test_dir/conf/default.conf"
grep -Fq 'proxy_pass http://btcpay;' "$test_dir/conf/default.conf"
grep -Fq 'include /etc/nginx/btcpay-routes/enabled-routes/*.conf;' "$test_dir/conf/default.conf"

# A matching certificate renders the redirect and TLS servers with their
# network, vhost, protocol, authentication, certificate, and HSTS settings.
grep -Fq 'server_name secure.test;' "$test_dir/conf/default.conf"
grep -Fq 'location ^~ /.well-known/acme-challenge/' "$test_dir/conf/default.conf"
grep -Fq "return 301 https://\$host\$request_uri;" "$test_dir/conf/default.conf"
grep -Fq 'include /etc/nginx/network_internal.conf;' "$test_dir/conf/default.conf"
grep -Fq 'include /etc/nginx/vhost.d/secure.test;' "$test_dir/conf/default.conf"
grep -Fq 'uwsgi_pass uwsgi://secure_test;' "$test_dir/conf/default.conf"
grep -Fq '/etc/nginx/htpasswd/secure.test;' "$test_dir/conf/default.conf"
grep -Fq 'ssl_certificate /etc/nginx/certs/secure.crt;' "$test_dir/conf/default.conf"
grep -Fq 'add_header Strict-Transport-Security "max-age=1234" always;' "$test_dir/conf/default.conf"

# A .local host without its own certificate is proxied through the default
# certificate with the same access, vhost, protocol, and root settings.
grep -Fq 'server_name service.local;' "$test_dir/conf/default.conf"
grep -Fq 'root   /srv/service;' "$test_dir/conf/default.conf"
grep -Fq 'fastcgi_pass service_local;' "$test_dir/conf/default.conf"
grep -Fq 'include /etc/nginx/vhost.d/default;' "$test_dir/conf/default.conf"
grep -Fq 'include /etc/nginx/vhost.d/default_location;' "$test_dir/conf/default.conf"
grep -Fq 'ssl_certificate /etc/nginx/certs/default.crt;' "$test_dir/conf/default.conf"
grep -Fq 'server_name fallback.test;' "$test_dir/conf/default.conf"
grep -Fq 'ssl_reject_handshake on;' "$test_dir/conf/default.conf"

docker run --rm \
    -v "$test_dir/certs:/etc/nginx/certs:ro" \
    -v "$test_dir/conf:/etc/nginx/conf.d:ro" \
    -v "$test_dir/htpasswd:/etc/nginx/htpasswd:ro" \
    -v "$test_dir/vhost:/etc/nginx/vhost.d:ro" \
    -v "$test_dir/html:/usr/share/nginx/html:ro" \
    -v "$test_dir/fastcgi.conf:/etc/nginx/fastcgi.conf:ro" \
    -v "$test_dir/network_internal.conf:/etc/nginx/network_internal.conf:ro" \
    -v "$repo_dir/nginx:/etc/nginx/btcpay-routes:ro" \
    "$nginx_image" nginx -t

printf 'Nginx template tests passed\n'
