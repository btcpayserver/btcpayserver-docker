#!/bin/bash

set -euo pipefail

manifest="${1:-Generated/manifest.json}"
[[ -f "$manifest" ]] || { printf 'Generated manifest does not exist: %s\n' "$manifest" >&2; exit 1; }

jq -e '(.secrets // []) | type == "array" and all(.[]; type == "string" and length > 0)' \
    "$manifest" >/dev/null || { printf 'Generated manifest contains invalid secrets metadata\n' >&2; exit 1; }

generated_dir="$(cd -- "$(dirname -- "$manifest")" && pwd -P)"
repository_dir="$(cd -- "$generated_dir/.." && pwd -P)"
secret_root="$repository_dir/secrets"

while IFS= read -r secret; do
    [[ "$secret" != /* && "$secret" != *$'\n'* && "$secret" != *$'\r'* ]] || {
        printf 'Invalid secret path: %q\n' "$secret" >&2
        exit 1
    }

    [[ "$secret" == ../secrets/* ]] || {
        printf 'Secret path must be under ../secrets/: %s\n' "$secret" >&2
        exit 1
    }
    relative_path="${secret#../secrets/}"
    [[ -n "$relative_path" && "$relative_path" != */../* && "$relative_path" != ../* && "$relative_path" != */.. &&
       "$relative_path" != */./* && "$relative_path" != ./* && "$relative_path" != */. && "$relative_path" != *//* ]] || {
        printf 'Invalid secret path: %s\n' "$secret" >&2
        exit 1
    }

    [[ ! -L "$secret_root" ]] || { printf 'Secrets directory must not be a symlink: %s\n' "$secret_root" >&2; exit 1; }
    if [[ ! -e "$secret_root" ]]; then
        mkdir -- "$secret_root"
    fi
    [[ -d "$secret_root" ]] || { printf 'Secrets path is not a directory: %s\n' "$secret_root" >&2; exit 1; }
    chmod 700 -- "$secret_root"

    secret_path="$secret_root/$relative_path"
    secret_dir="$(dirname -- "$secret_path")"
    current_dir="$secret_root"
    remaining_dir="${relative_path%/*}"
    if [[ "$remaining_dir" != "$relative_path" ]]; then
        while [[ -n "$remaining_dir" ]]; do
            component="${remaining_dir%%/*}"
            current_dir="$current_dir/$component"
            [[ ! -L "$current_dir" ]] || { printf 'Secret directory must not be a symlink: %s\n' "$current_dir" >&2; exit 1; }
            if [[ ! -e "$current_dir" ]]; then
                mkdir -- "$current_dir"
            fi
            [[ -d "$current_dir" ]] || { printf 'Secret path component is not a directory: %s\n' "$current_dir" >&2; exit 1; }
            chmod 700 -- "$current_dir"
            if [[ "$remaining_dir" == "$component" ]]; then
                break
            fi
            remaining_dir="${remaining_dir#*/}"
        done
    fi

    [[ ! -L "$secret_path" ]] || { printf 'Secret path must not be a symlink: %s\n' "$secret_path" >&2; exit 1; }
    if [[ -e "$secret_path" ]]; then
        [[ -f "$secret_path" ]] || { printf 'Secret path is not a regular file: %s\n' "$secret_path" >&2; exit 1; }
        continue
    fi

    temporary="$(mktemp "$secret_dir/.btcpay-secret.XXXXXX")"
    secret_value=""
    while (( ${#secret_value} < 64 )); do
        secret_value+="$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | LC_ALL=C tr -dc 'a-zA-Z0-9')"
    done
    printf '%s' "${secret_value:0:64}" > "$temporary"
    chmod 644 -- "$temporary"
    if [[ ! -e "$secret_path" && ! -L "$secret_path" ]]; then
        mv -n -- "$temporary" "$secret_path"
        printf 'Generated secret %s\n' "$secret"
    fi
    rm -f -- "$temporary"
done < <(jq -r '(.secrets // [])[]' "$manifest")
