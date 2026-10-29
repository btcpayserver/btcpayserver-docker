#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failed=false
mount_pattern='^[[:space:]]*-[[:space:]]*"?((/|\./|\.\./|~)[^":]*):([^":]+)(:([^"]*))?"?[[:space:]]*$'

for fragment in "$repo_dir"/docker-compose-generator/docker-fragments/*.yml; do
    socket_mounts=0
    unlabeled=0
    while IFS= read -r line; do
        [[ "$line" =~ $mount_pattern ]] || continue
        source="${BASH_REMATCH[1]}"
        options="${BASH_REMATCH[5]}"
        if [[ "$source" == "/var/run/docker.sock" ]]; then
            socket_mounts=$((socket_mounts + 1))
        elif [[ ",$options," != *,z,* && ",$options," != *,Z,* ]]; then
            printf '%s: host bind mount needs the z option: %s\n' "${fragment#"$repo_dir"/}" "$source" >&2
            unlabeled=$((unlabeled + 1))
        fi
    done < "$fragment"

    disabled="$(grep -o 'label=disable' "$fragment" | wc -l || true)"
    if (( socket_mounts > disabled )); then
        printf '%s: services mounting the Docker socket need security_opt label=disable\n' "${fragment#"$repo_dir"/}" >&2
        failed=true
    fi
    (( unlabeled == 0 )) || failed=true
done

for mount in Generated docker-compose-generator/docker-fragments docker-compose-generator/crypto-definitions.json; do
    if ! grep -qF -- "-v \"\$(pwd)/$mount:/app/" "$repo_dir/build.sh" ||
       ! grep -F -- "-v \"\$(pwd)/$mount:/app/" "$repo_dir/build.sh" | grep -q ':z"'; then
        printf 'build.sh: generator bind mount needs the z option: %s\n' "$mount" >&2
        failed=true
    fi
done

if $failed; then
    exit 1
fi
printf 'SELinux label tests passed\n'
