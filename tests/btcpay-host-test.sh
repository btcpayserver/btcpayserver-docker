#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
cleanup() {
    # Stop any worker still waiting for a release after a failed assertion.
    for pid_file in "$test_dir"/*/pid; do
        if [ -f "$pid_file" ] && [ ! -f "${pid_file%/*}/finished" ]; then
            kill "$(cat "$pid_file")" 2>/dev/null || true
        fi
    done
    rm -rf "$test_dir"
}
trap cleanup EXIT

mkdir -p "$test_dir/bin" "$test_dir/deployment/btcpayserver-docker"
profile="$test_dir/profile"
printf 'export BTCPAY_BASE_DIRECTORY=%q\n' "$test_dir/deployment" > "$profile"
# Use the real wrapper without reading or modifying the machine's deployment.
sed "s|/etc/profile.d/btcpay-env.sh|$profile|g" "$repo_dir/btcpay-host" > "$test_dir/bin/btcpay-host"
chmod +x "$test_dir/bin/btcpay-host"

cat > "$test_dir/bin/worker" <<'EOF'
#!/bin/bash
set -euo pipefail
echo $$ > "$TEST_CASE/pid"
printf '%s\n' "$@" > "$TEST_CASE/arguments"
printf '%s\n' "${BTCPAY_UPDATE_DETACHED-unset}" > "$TEST_CASE/update-detached"
ps -o sid= -p $$ | tr -d ' ' > "$TEST_CASE/session"
if [ -t 1 ]; then
    touch "$TEST_CASE/terminal"
else
    if read -r input; then
        echo 'Worker inherited caller stdin' >&2
        exit 99
    fi
fi
echo 'Maintenance started'
echo 'Maintenance diagnostic' >&2
touch "$TEST_CASE/started"
for ((i=0; i<500; i++)); do
    if [ -f "$TEST_CASE/release" ]; then
        echo 'Maintenance finished'
        touch "$TEST_CASE/finished"
        exit "${TEST_STATUS:-0}"
    fi
    sleep 0.02
done
echo 'Timed out waiting for test release' >&2
exit 98
EOF
chmod +x "$test_dir/bin/worker"
for script in btcpay-update.sh btcpay-restart.sh changedomain.sh btcpay-clean.sh; do
    ln -s worker "$test_dir/bin/$script"
done

real_setsid="$(command -v setsid)"
cat > "$test_dir/bin/setsid" <<EOF
#!/bin/bash
echo detached >> "\$TEST_CASE/setsid-calls"
exec "$real_setsid" "\$@"
EOF
chmod +x "$test_dir/bin/setsid"

export PATH="$test_dir/bin:$PATH"
unset BTCPAY_UPDATE_DETACHED

wait_for() {
    local description="$1"
    local attempt
    shift
    for ((attempt=0; attempt<500; attempt++)); do
        if "$@" 2>/dev/null; then
            return
        fi
        sleep 0.02
    done
    printf 'Timed out waiting for %s\n' "$description" >&2
    return 1
}

new_case() {
    export TEST_CASE="$test_dir/$1"
    mkdir "$TEST_CASE"
}

for command in update restart changedomain; do
    args=("$command")
    [ "$command" != changedomain ] || args+=(new.example.com)
    log="$test_dir/deployment/btcpay-host-$command.log"

    new_case "connected-$command"
    printf 'stale output\n' > "$log"
    chmod 644 "$log"
    export TEST_STATUS=23
    btcpay-host "${args[@]}" <<< 'must not reach the worker' > "$TEST_CASE/output" 2> "$TEST_CASE/error" &
    caller=$!
    wait_for 'worker startup' test -f "$TEST_CASE/started"
    wait_for 'live stdout' grep -q 'Maintenance started' "$TEST_CASE/output"
    wait_for 'live stderr' grep -Fxq 'Maintenance diagnostic' "$TEST_CASE/output"
    if grep -q 'stale output' "$TEST_CASE/output"; then
        echo 'Stream included output from the previous invocation' >&2
        exit 1
    fi
    [ "$(stat -c %a "$log")" = 600 ]
    [ "$(cat "$TEST_CASE/update-detached")" = 1 ]
    [ "$(wc -l < "$TEST_CASE/setsid-calls")" -eq 1 ]
    [ "$(cat "$TEST_CASE/session")" != "$(ps -o sid= -p "$caller" | tr -d ' ')" ]
    [ ! -f "$TEST_CASE/finished" ]
    if [ "$command" = changedomain ]; then
        grep -Fxq new.example.com "$TEST_CASE/arguments"
    fi
    touch "$TEST_CASE/release"
    status=0
    wait "$caller" || status=$?
    [ "$status" -eq 23 ]
    grep -Fxq 'Maintenance finished' "$TEST_CASE/output"

    new_case "disconnected-$command"
    export TEST_STATUS=0
    # Simulate the SSH session disappearing: SIGHUP its entire process group,
    # including the wrapper and tail, while the maintenance worker is running.
    "$real_setsid" btcpay-host "${args[@]}" > "$TEST_CASE/output" 2> "$TEST_CASE/error" &
    caller=$!
    wait_for 'worker startup' test -f "$TEST_CASE/started"
    [ "$(cat "$TEST_CASE/session")" != "$caller" ]
    kill -HUP -- "-$caller"
    wait "$caller" 2>/dev/null || true
    touch "$TEST_CASE/release"
    wait_for 'completion after disconnect' test -f "$TEST_CASE/finished"
    grep -Fxq 'Maintenance finished' "$log"

    new_case "closed-pipe-$command"
    # Closing just the output reader must not kill the worker either: tail may
    # get SIGPIPE, but the worker writes exclusively to its private log.
    btcpay-host "${args[@]}" > >(head -n 1 > "$TEST_CASE/output") 2> "$TEST_CASE/error" &
    caller=$!
    wait_for 'output before reader disconnect' grep -q 'Maintenance started' "$TEST_CASE/output"
    touch "$TEST_CASE/release"
    wait "$caller"
    test -f "$TEST_CASE/finished"
    grep -Fxq 'Maintenance finished' "$log"
done

# Reject invalid domains before starting a worker or truncating its log.
log="$test_dir/deployment/btcpay-host-changedomain.log"
cp "$log" "$test_dir/previous-log"
if btcpay-host changedomain 'https://invalid.example.com' > "$test_dir/output" 2> "$test_dir/error"; then
    echo 'Invalid domain was accepted' >&2
    exit 1
fi
grep -Fxq 'The domain must be a valid domain name without a protocol.' "$test_dir/error"
cmp "$log" "$test_dir/previous-log"

# An interactive host call still uses the terminal and does not mark the update
# as already detached. util-linux script supplies a pty without requiring one
# on the test runner itself.
new_case interactive
touch "$TEST_CASE/release"
export TEST_STATUS=0
script -q -e -c 'btcpay-host restart' "$TEST_CASE/transcript" > "$TEST_CASE/output"
test -f "$TEST_CASE/terminal"
[ "$(cat "$TEST_CASE/update-detached")" = unset ]
grep -q 'Maintenance finished' "$TEST_CASE/output"

# Non-disruptive commands do not go through the detached maintenance helper.
new_case clean
touch "$TEST_CASE/release"
btcpay-host clean < /dev/null > "$TEST_CASE/output" 2> "$TEST_CASE/error"
[ "$(cat "$TEST_CASE/update-detached")" = unset ]
[ ! -f "$TEST_CASE/setsid-calls" ]

# Exercise the actual update bootstrap and detachment code, replacing only the
# work after it with our stub so the test cannot touch Docker or host tooling.
update="$test_dir/deployment/btcpayserver-docker/btcpay-update.sh"
awk '
    /^if ! \[ -f "\/etc\/docker\/daemon.json"/ { found = 1; exit }
    { print }
    END { if (!found) exit 1 }
' "$repo_dir/btcpay-update.sh" |
    sed "s|/etc/profile.d/btcpay-env.sh|$profile|g" > "$update"
# shellcheck disable=SC2016 # Expanded by the sandboxed update, not this writer.
printf '\nexec "$TEST_WORKER"\n' >> "$update"
bash -n "$update"
chmod +x "$update"
rm "$test_dir/bin/btcpay-update.sh"
ln -s "$update" "$test_dir/bin/btcpay-update.sh"
export TEST_WORKER="$test_dir/bin/worker"
cat > "$test_dir/bin/git" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$TEST_CASE/git-calls"
EOF
chmod +x "$test_dir/bin/git"

for caller in old new; do
    new_case "bootstrap-$caller"
    touch "$TEST_CASE/release"
    export TEST_STATUS=37
    status=0
    if [ "$caller" = old ]; then
        # An already-running pre-fix wrapper directly invokes the update script.
        btcpay-update.sh > "$TEST_CASE/output" 2> "$TEST_CASE/error" || status=$?
        log="$test_dir/deployment/btcpay-update.log"
    else
        btcpay-host update > "$TEST_CASE/output" 2> "$TEST_CASE/error" || status=$?
        log="$test_dir/deployment/btcpay-host-update.log"
    fi
    [ "$status" -eq 37 ]
    grep -Fxq 'pull --force' "$TEST_CASE/git-calls"
    [ "$(wc -l < "$TEST_CASE/setsid-calls")" -eq 1 ]
    grep -Fxq 'Maintenance finished' "$TEST_CASE/output"
    [ "$(stat -c %a "$log")" = 600 ]
done

# Run the unchanged domain script end-to-end through the new wrapper, with
# isolated profile/environment files and no-op Compose helpers.
domain_script="$test_dir/deployment/btcpayserver-docker/changedomain.sh"
sed "s|/etc/profile.d/btcpay-env.sh|$profile|g" "$repo_dir/changedomain.sh" > "$domain_script"
chmod +x "$domain_script"
rm "$test_dir/bin/changedomain.sh"
ln -s "$domain_script" "$test_dir/bin/changedomain.sh"
{
    printf 'export BTCPAY_ENV_FILE=%q\n' "$test_dir/deployment/.env"
    printf 'export REVERSEPROXY_DEFAULT_HOST=old.example.com\n'
} >> "$profile"
printf 'BTCPAY_HOST=old.example.com\n' > "$test_dir/deployment/.env"
cat > "$test_dir/deployment/btcpayserver-docker/helpers.sh" <<'EOF'
btcpay_update_docker_env() {
    printf 'BTCPAY_HOST=%s\n' "$BTCPAY_HOST" > "$BTCPAY_ENV_FILE"
}
btcpay_up() { :; }
EOF
new_case domain-script
btcpay-host changedomain new.example.com > "$TEST_CASE/output" 2> "$TEST_CASE/error"
grep -Fxq 'Changing domain from "old.example.com" to "new.example.com"' "$TEST_CASE/output"
grep -Fxq 'BTCPAY_HOST=new.example.com' "$test_dir/deployment/.env"

printf 'btcpay-host tests passed\n'
