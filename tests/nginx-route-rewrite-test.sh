#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
container="btcpay-route-rewrite-$$"
cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
    rm -rf -- "$test_dir"
}
trap cleanup EXIT

# Use the shipped route snippets with local URI-echo backends in one isolated
# nginx container using an ephemeral loopback port, without BTCPay services.
for route in lnd-rest clightning-rest; do
    # shellcheck disable=SC2016 # Match literal nginx variable names.
    sed -e 's/set $btcpay_route_upstream lnd_bitcoin;/set $btcpay_route_upstream 127.0.0.1;/' \
        -e 's/set $btcpay_route_upstream clightning_bitcoin;/set $btcpay_route_upstream 127.0.0.1;/' \
        "$repo_dir/nginx/routes/$route.conf" > "$test_dir/$route.conf"
done
cat > "$test_dir/nginx.conf" <<'EOF'
events {}
http {
    access_log off;
    server {
        listen 80;
        include /etc/nginx/route-test/lnd-rest.conf;
        include /etc/nginx/route-test/clightning-rest.conf;
        location / { return 404; }
    }
    server {
        listen 8080;
        listen 3010;
        return 200 "$request_method $request_uri";
    }
}
EOF
nginx_image="$("$repo_dir/tests/docker-fragment-image.sh" nginx)"
docker run -d --name "$container" -p 127.0.0.1::80 \
    -v "$test_dir:/etc/nginx/route-test:ro" \
    -v "$test_dir/nginx.conf:/etc/nginx/nginx.conf:ro" "$nginx_image" >/dev/null
port="$(docker inspect -f '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' "$container")"
python3 - "$port" <<'PY'
import http.client
import sys
import time

port = int(sys.argv[1])

def request(method, path):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    try:
        connection.request(method, path, body="payload" if method == "POST" else None)
        response = connection.getresponse()
        return response.status, response.read().decode()
    finally:
        connection.close()

for attempt in range(50):
    try:
        request("GET", "/")
        break
    except OSError:
        if attempt == 49:
            raise
        time.sleep(0.1)

for route in ("lnd-rest/btc", "clightning-rest/btc"):
    for method in ("GET", "POST"):
        path = f"/{route}/v1/getinfo?verbose=1"
        assert request(method, path) == (200, f"{method} /v1/getinfo?verbose=1")
        path = f"/{route}/v1/getinfo%0Ax?verbose=1"
        assert request(method, path) == (200, f"{method} {path}")

for name in ("genseed", "initwallet", "unlockwallet", "changepassword", "state", "state/subscribe"):
    for method in ("GET", "POST"):
        path = f"/lnd-rest/btc/v1/{name}"
        assert request(method, path)[0] == 500
        path += "%0Ax?verbose=1"
        assert request(method, path) == (200, f"{method} {path}")

print("Nginx route rewrite tests passed")
PY
