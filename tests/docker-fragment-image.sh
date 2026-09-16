#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="${1:?usage: docker-fragment-image.sh SERVICE}"
fragment="$repo_dir/docker-compose-generator/docker-fragments/nginx.yml"

image="$(awk -v service="$service" '
    $0 == "  " service ":" { in_service = 1; next }
    in_service && /^  [^ ]/ { exit }
    in_service && /^    image: / {
        sub(/^    image: /, "")
        print
        exit
    }
' "$fragment")"

if [ -z "$image" ]; then
    printf 'No image found for service %s in %s\n' "$service" "$fragment" >&2
    exit 1
fi

printf '%s\n' "$image"
