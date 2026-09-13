#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "$repo_dir/.log-archive-test.XXXXXX")"
cleanup() {
    case "$test_dir" in
        "$repo_dir"/.log-archive-test.*) rm -rf -- "$test_dir" ;;
        *) return 1 ;;
    esac
}
trap cleanup EXIT
. "$repo_dir/helpers.sh"

export BTCPAY_BASE_DIRECTORY="$test_dir/host with spaces"
export BTCPAY_ENV_FILE="$BTCPAY_BASE_DIRECTORY/.env"
export BTCPAY_DOCKER_COMPOSE="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker/Generated/docker-compose.generated.yml"
export COMPOSE_FILE="an-unrelated-compose-file.yml"
mkdir -p "$BTCPAY_BASE_DIRECTORY"
archive_dir="$BTCPAY_BASE_DIRECTORY/btcpay-update-logs"
calls_file="$test_dir/compose-calls"
mode=success

docker-compose() {
    printf '%s\n' "$*" >> "$calls_file"
    [ "$PWD" = "$BTCPAY_BASE_DIRECTORY" ] || return 1
    if [ "$1" = -f ]; then
        [ "$#" -eq 5 ] && [ "$2" = "$BTCPAY_DOCKER_COMPOSE" ] &&
            [ "$3 $4 $5" = 'config --format json' ] || return 1
        case "$mode" in
            config-failure) return 1 ;;
            invalid-project) printf '{"name":null}\n' ;;
            *) printf '{"name":"custom-project"}\n' ;;
        esac
    else
        [ "$#" -eq 5 ] && [ "$*" = '-p custom-project logs --no-color --timestamps' ] || return 1
        [ -z "$COMPOSE_FILE" ] || return 1
        # Project-only retrieval includes old services absent from the new YAML.
        printf 'btcpayserver | 2026-09-13T00:00:00Z application output\n'
        printf 'retired-service | 2026-09-13T00:00:01Z previous service output\n'
        if [ "$mode" = log-failure ]; then
            printf 'Docker log retrieval failed\n' >&2
            return 1
        fi
        if [ "$mode" = unsupported-driver ]; then
            printf 'Warning: driver does not support local log retrieval\n' >&2
        fi
    fi
}

run_archive() {
    set +e
    output="$(btcpay_archive_logs 2>&1)"
    status=$?
    set -e
}

original_umask="$(umask)"
original_pwd="$PWD"
run_archive
[ "$status" -eq 0 ]
[ "$(umask)" = "$original_umask" ]
[ "$PWD" = "$original_pwd" ]
[ "$COMPOSE_FILE" = an-unrelated-compose-file.yml ]
archives=("$archive_dir"/update-*.log.gz)
[ "${#archives[@]}" -eq 1 ]
contents="$(gzip -cd "${archives[0]}")"
[[ "$contents" == *'application output'* ]]
[[ "$contents" == *'retired-service'* ]]
[[ "$contents" == *'2026-09-13T00:00:01Z'* ]]
if [[ "$OSTYPE" != msys* && "$OSTYPE" != cygwin* ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
        [ "$(stat -f '%Lp' "$archive_dir")" = 700 ]
        [ "$(stat -f '%Lp' "${archives[0]}")" = 600 ]
    else
        [ "$(stat -c '%a' "$archive_dir")" = 700 ]
        [ "$(stat -c '%a' "${archives[0]}")" = 600 ]
    fi
fi

# Only completed archives count toward retention; unrelated files survive.
printf 'leave this file alone\n' > "$archive_dir/notes.txt"
for n in 1 2 3 4 5; do
    printf 'old archive %s\n' "$n" | gzip > "$archive_dir/update-old-$n.log.gz"
    touch -t "20200101000$n" "$archive_dir/update-old-$n.log.gz"
done
run_archive
[ "$status" -eq 0 ]
archives=("$archive_dir"/update-*.log.gz)
[ "${#archives[@]}" -eq 5 ]
[ ! -e "$archive_dir/update-old-1.log.gz" ]
[ ! -e "$archive_dir/update-old-2.log.gz" ]
[ -f "$archive_dir/notes.txt" ]

for mode in log-failure config-failure invalid-project; do
    previous_archives=("$archive_dir"/update-*.log.gz)
    run_archive
    [ "$status" -ne 0 ]
    archives=("$archive_dir"/update-*.log.gz)
    [ "${archives[*]}" = "${previous_archives[*]}" ]
    for archive in "${archives[@]}"; do gzip -t "$archive"; done
done
mode=success
shopt -s nullglob
temporary_files=("$archive_dir"/.update-*)
[ "${#temporary_files[@]}" -eq 0 ]

# Compression and storage failures must not publish an archive or prune old ones.
for failing_command in gzip mkdir mktemp mv; do
    set +e
    output="$(eval "$failing_command() { return 1; }"; btcpay_archive_logs 2>&1)"
    status=$?
    set -e
    [ "$status" -ne 0 ]
    archives=("$archive_dir"/update-*.log.gz)
    [ "${archives[*]}" = "${previous_archives[*]}" ]
    temporary_files=("$archive_dir"/.update-*)
    [ "${#temporary_files[@]}" -eq 0 ]
done

# Unsupported local log drivers produce a visible Compose warning, not an error.
mode=unsupported-driver
run_archive
[ "$status" -eq 0 ]
[[ "$output" == *'driver does not support local log retrieval'* ]]
mode=success

for invalid_count in -1 abc 1.5 10000; do
    BTCPAY_LOG_ARCHIVE_COUNT="$invalid_count" run_archive
    [ "$status" -ne 0 ]
done
BTCPAY_LOG_ARCHIVE_COUNT=0 run_archive
[ "$status" -eq 0 ]
[ -z "$output" ]
BTCPAY_LOG_ARCHIVE_COUNT=02 run_archive
[ "$status" -eq 0 ]
archives=("$archive_dir"/update-*.log.gz)
[ "${#archives[@]}" -eq 2 ]

# Saving settings must carry the default and an explicit opt-out into .env.
for setting in default 0 12; do
    (
        set +u
        BTCPAY_ENV_FILE="$test_dir/persisted.env"
        BTCPAY_ENABLE_SSH=false
        if [ "$setting" = default ]; then
            unset BTCPAY_LOG_ARCHIVE_COUNT
        else
            BTCPAY_LOG_ARCHIVE_COUNT="$setting"
        fi
        btcpay_update_docker_env
    )
    saved_environment="$(< "$test_dir/persisted.env")"
    expected="$setting"
    [ "$setting" = default ] && expected=5
    [[ "$saved_environment" == *"BTCPAY_LOG_ARCHIVE_COUNT=$expected"$'\n'* ]]
done

# Exercise the actual updater's final sequence with all host mutations stubbed.
install_tooling() { :; }
btcpay_update_docker_env() { :; }
btcpay_up() { printf 'containers replaced\n' > "$test_dir/replaced"; }
BTCPAY_UPDATE_CLEAN=false
mode=log-failure
set +e
output="$(set -e; . <(sed -n '/^install_tooling$/,$p' "$repo_dir/btcpay-update.sh") 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ]
[ ! -e "$test_dir/replaced" ]
mode=success
output="$(set -e; . <(sed -n '/^install_tooling$/,$p' "$repo_dir/btcpay-update.sh") 2>&1)"
[ -e "$test_dir/replaced" ]

printf 'Update log archive tests passed.\n'
