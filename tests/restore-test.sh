#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Do not let a real installation's profile replace the isolated fixture paths.
profile_path=/etc/profile.d/btcpay-env.sh
if [ -f "$profile_path" ]; then
  printf 'Run restore tests in an environment without %s.\n' "$profile_path" >&2
  exit 1
fi

test_dir="$(mktemp -d)"
cleanup() {
  gpgconf --homedir "$test_dir/gnupg" --kill gpg-agent 2>/dev/null || true
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

export GNUPGHOME="$test_dir/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export BTCPAYGEN_REVERSEPROXY=none
export BTCPAY_DATABASE_READY_TIMEOUT=1
export COMPOSE_HTTP_TIMEOUT=180
export RESTORE_TEST_RUNNER_PID=$$

fail_test() {
  printf 'Restore test failed: %s\n' "$*" >&2
  if [ -f "${case_dir:-}/restore.log" ]; then
    sed -n '1,200p' "$case_dir/restore.log" >&2
  fi
  exit 1
}

# Execute the real script and helper functions, with all Docker access mocked.
id() {
  if [ "$*" = -u ]; then
    printf '0\n'
  else
    command id "$@"
  fi
}

docker() {
  printf 'docker %s\n' "$*" >> "$RESTORE_TEST_COMMANDS"
  case "$*" in
    'volume inspect generated_btcpay_datadir --format={{.Mountpoint}}')
      printf '%s/generated_btcpay_datadir/_data\n' "$RESTORE_TEST_VOLUMES"
      ;;
    'volume create generated_postgres_datadir' | 'volume create generated_mariadb_datadir')
      [ -n "$RESTORE_TEST_BACKUP_MODE" ]
      ;;
    'exec postgres pg_dumpall -c -U postgres' | \
    'exec mariadb mysqldump -u root -pwordpressdb -A --add-drop-database')
      [ -n "$RESTORE_TEST_BACKUP_MODE" ] || return 1
      [ -f "$RESTORE_TEST_CASE/running-all" ] ||
        [ -f "$RESTORE_TEST_CASE/running-$2" ] || return 1
      if [ "$RESTORE_TEST_BACKUP_MODE" = migrate ] && [ -f "$RESTORE_TEST_CASE/running-all" ]; then
        printf 'Migration must stop the application stack before database dumps.\n' >&2
        return 1
      fi
      if [ "$2" = postgres ]; then
        printf '%s\n' '-- PostgreSQL restore test dump' 'SELECT 42;'
      else
        printf '%s\n' '-- MariaDB restore test dump' 'SELECT 43;'
      fi
      ;;
    'exec postgres pg_isready --quiet --username=postgres' | \
    'exec mariadb mysqladmin --user=root --password=wordpressdb --silent ping')
      return 0
      ;;
    'exec -i postgres psql -X --quiet --set=ON_ERROR_STOP=1 --username=postgres --dbname=postgres')
      command cat > "$RESTORE_TEST_CASE/postgres-import.sql"
      if [ "$RESTORE_TEST_INTERRUPT_IMPORT" = true ]; then
        # In this pipeline subshell, $$ remains the isolated restore process's
        # PID. Never signal the test runner or its process group.
        [ "$$" != "$RESTORE_TEST_RUNNER_PID" ] || return 1
        [ -f "$RESTORE_TEST_CASE/running-postgres" ] &&
          [ -f "$RESTORE_TEST_CASE/running-mariadb" ] || return 1
        touch "$RESTORE_TEST_CASE/interrupted"
        kill -TERM "$$"
      fi
      [ "$RESTORE_TEST_FAIL_IMPORT" != postgres ]
      ;;
    'exec -i mariadb mysql --user=root --password=wordpressdb')
      command cat > "$RESTORE_TEST_CASE/mariadb-import.sql"
      [ "$RESTORE_TEST_FAIL_IMPORT" != mariadb ]
      ;;
    *)
      printf 'Unexpected docker command: %s\n' "$*" >&2
      return 1
      ;;
  esac
}

docker-compose() {
  [ "$1" = -f ] && [ "$2" = "$BTCPAY_DOCKER_COMPOSE" ] || return 1
  shift 2
  printf 'compose %s\n' "$*" >> "$RESTORE_TEST_COMMANDS"
  if [ "$1" = up ] && [ -n "$RESTORE_TEST_EXPECT_SECRETS" ]; then
    if ! cmp "$RESTORE_TEST_EXPECT_SECRETS" "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker/secrets/test_password"; then
      printf 'Source secrets must be restored before starting containers.\n' >&2
      return 1
    fi
  fi
  case "$*" in
    'config --services')
      [ -n "$RESTORE_TEST_BACKUP_MODE" ] || return 1
      printf '%s\n' postgres mariadb lnd_bitcoin
      ;;
    'down -t 180')
      if [ ! -f "$RESTORE_TEST_CASE/stop-failed" ] &&
          { [ "$RESTORE_TEST_FAIL_STOP" = initial ] ||
            { [ "$RESTORE_TEST_FAIL_STOP" = final ] && [ -f "$RESTORE_TEST_CASE/running-postgres" ]; }; }; then
        touch "$RESTORE_TEST_CASE/stop-failed"
        printf 'Injected container-shutdown failure.\n' >&2
        return 1
      fi
      rm -f -- "$RESTORE_TEST_CASE/running-all" \
        "$RESTORE_TEST_CASE/running-postgres" "$RESTORE_TEST_CASE/running-mariadb"
      if [ "$RESTORE_TEST_CREATE_LND_ON_STOP" = true ]; then
        mkdir -p "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data"
        printf 'created during shutdown\n' > "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/sentinel"
      fi
      ;;
    'up --no-deps -d postgres' | 'up -d --no-deps postgres')
      touch "$RESTORE_TEST_CASE/running-postgres"
      ;;
    'up --no-deps -d mariadb' | 'up -d --no-deps mariadb')
      touch "$RESTORE_TEST_CASE/running-mariadb"
      ;;
    'ps -q postgres' | 'ps -q mariadb')
      if [ -f "$RESTORE_TEST_CASE/running-all" ] || [ -f "$RESTORE_TEST_CASE/running-$3" ]; then
        printf '%s\n' "$3"
      fi
      ;;
    'up --remove-orphans -d -t 180')
      touch "$RESTORE_TEST_CASE/running-all"
      if [ "$RESTORE_TEST_FAIL_RESTART" = true ]; then
        printf 'Injected failure after partially starting the stack.\n' >&2
        return 1
      fi
      if [ "$RESTORE_TEST_REWRITE_SCB" = true ]; then
        local scb
        for scb in "$RESTORE_TEST_VOLUMES"/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/*/channel.backup; do
          [ -f "$scb" ] || continue
          printf 'empty-channel-list written by simulated LND startup\n' > "$scb"
        done
      fi
      ;;
    *)
      printf 'Unexpected docker-compose command: %s\n' "$*" >&2
      return 1
      ;;
  esac
}

cp() {
  if [ "$RESTORE_TEST_FAIL_OVERLAY" = true ] && [ "${1:-}" = -a ]; then
    printf 'Injected volume-copy failure.\n' >&2
    return 1
  fi
  command cp "$@"
}

tar() {
  if [ "${1:-}" = -czf ] && [ -n "$RESTORE_TEST_BACKUP_MODE" ]; then
    if [ -f "$RESTORE_TEST_CASE/running-all" ] ||
        [ -f "$RESTORE_TEST_CASE/running-postgres" ] || [ -f "$RESTORE_TEST_CASE/running-mariadb" ]; then
      printf 'All source containers must be stopped while archiving Lightning data.\n' >&2
      return 1
    fi
  fi
  command tar "$@"
}
export -f id docker docker-compose cp tar

new_case() {
  case_dir="$(mktemp -d "$test_dir/case.XXXXXX")"
  export RESTORE_TEST_CASE="$case_dir"
  export RESTORE_TEST_VOLUMES="$case_dir/docker/volumes"
  export RESTORE_TEST_COMMANDS="$case_dir/commands.log"
  export RESTORE_TEST_FAIL_IMPORT=""
  export RESTORE_TEST_INTERRUPT_IMPORT=false
  export RESTORE_TEST_FAIL_RESTART=false
  export RESTORE_TEST_FAIL_STOP=""
  export RESTORE_TEST_FAIL_OVERLAY=false
  export RESTORE_TEST_CREATE_LND_ON_STOP=false
  export RESTORE_TEST_REWRITE_SCB=false
  export RESTORE_TEST_BACKUP_MODE=""
  export RESTORE_TEST_EXPECT_SECRETS=""
  export BTCPAY_BASE_DIRECTORY="$case_dir"
  export BTCPAY_DOCKER_COMPOSE="$case_dir/compose.yml"
  export BTCPAY_ENV_FILE="$case_dir/.env"
  export BTCPAY_BACKUP_PASSPHRASE=""
  fixture_dir="$case_dir/archive-content"
  mkdir -p "$fixture_dir/volumes" "$RESTORE_TEST_VOLUMES/generated_btcpay_datadir/_data"
  # Restore now writes secrets/ here. Each source and destination needs its
  # own directory; a symlink to the checkout would change real secrets.
  mkdir "$case_dir/btcpayserver-docker"
  command cp "$repo_dir/helpers.sh" "$case_dir/btcpayserver-docker/helpers.sh"
  touch "$BTCPAY_DOCKER_COMPOSE" "$BTCPAY_ENV_FILE" "$RESTORE_TEST_COMMANDS" "$case_dir/running-all"
  printf 'existing destination settings\n' > "$RESTORE_TEST_VOLUMES/generated_btcpay_datadir/_data/settings.config"
}

fixture_file() {
  local path="$fixture_dir/$1"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "${2:-$1}" > "$path"
}

make_fixture() {
  local mode=$1
  local lightning=$2
  local network

  if [ "$mode" != legacy ]; then
    fixture_file btcpay-backup-mode "$mode"
  fi
  fixture_file volumes/generated_btcpay_datadir/_data/settings.config 'archived settings'
  printf '%s\n' '-- PostgreSQL restore test dump' 'SELECT 42;' | gzip > "$fixture_dir/postgres.sql.gz"
  printf '%s\n' '-- MariaDB restore test dump' 'SELECT 43;' | gzip > "$fixture_dir/mariadb.sql.gz"

  if [[ "$lightning" == lnd* ]]; then
    fixture_file volumes/generated_lnd_bitcoin_datadir/_data/admin.macaroon
    for network in mainnet testnet regtest; do
      fixture_file "volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/wallet.db"
      if [ "$lightning" != lnd-no-scb ]; then
        fixture_file "volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/channel.backup"
      fi
      if [ "$lightning" = lnd-full ]; then
        fixture_file "volumes/generated_lnd_bitcoin_datadir/_data/data/graph/$network/channel.db"
        fixture_file "volumes/generated_lnd_bitcoin_datadir/_data/data/graph/$network/sphinxreplay.db"
        fixture_file "volumes/generated_lnd_bitcoin_datadir/_data/data/graph/$network/wtclient.db"
      fi
    done
  elif [ "$lightning" = cln ]; then
    fixture_file volumes/generated_clightning_bitcoin_datadir/_data/bitcoin/lightningd.sqlite3
    fixture_file volumes/generated_clightning_bitcoin_datadir/_data/bitcoin/hsm_secret
  fi
}

pack_archive() {
  local format=${1:-plain}
  archive_path="$case_dir/backup.tar.gz"
  command tar -czf "$archive_path" -C "$fixture_dir" .
  if [ "$format" = encrypted ]; then
    export BTCPAY_BACKUP_PASSPHRASE=restore-test-passphrase
    gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 3 \
      --symmetric --output "$archive_path.gpg" "$archive_path" 3<<<"$BTCPAY_BACKUP_PASSPHRASE"
    archive_path="$archive_path.gpg"
  fi
}

expect_success() {
  if ! bash "$repo_dir/btcpay-restore.sh" "$@" > "$case_dir/restore.log" 2>&1; then
    fail_test "restore unexpectedly failed: $*"
  fi
}

expect_failure() {
  if bash "$repo_dir/btcpay-restore.sh" "$@" > "$case_dir/restore.log" 2>&1; then
    fail_test "restore unexpectedly succeeded: $*"
  else
    restore_status=$?
  fi
  if grep -q 'Unexpected docker' "$case_dir/restore.log"; then
    fail_test 'failure came from an unsupported mock command'
  fi
}

assert_untouched() {
  [ -f "$case_dir/running-all" ] || fail_test 'preflight failure stopped the running stack'
  grep -q '^existing destination settings$' "$RESTORE_TEST_VOLUMES/generated_btcpay_datadir/_data/settings.config" ||
    fail_test 'preflight failure overwrote destination settings'
  if grep -q '^compose \(up\|down\)' "$RESTORE_TEST_COMMANDS"; then
    fail_test 'preflight failure changed container state'
  fi
}

assert_stopped() {
  [ ! -e "$case_dir/running-all" ] && [ ! -e "$case_dir/running-postgres" ] &&
    [ ! -e "$case_dir/running-mariadb" ] || fail_test 'containers were not all left stopped'
  if [ "${1:-}" != allow-restart ] && grep -q '^compose up --remove-orphans' "$RESTORE_TEST_COMMANDS"; then
    fail_test 'migration or failed restore started the whole stack'
  fi
}

assert_imports() {
  grep -q '^SELECT 42;$' "$case_dir/postgres-import.sql" || fail_test 'Postgres dump was not imported'
  grep -q '^SELECT 43;$' "$case_dir/mariadb-import.sql" || fail_test 'MariaDB dump was not imported'
  cmp "$fixture_dir/volumes/generated_btcpay_datadir/_data/settings.config" \
    "$RESTORE_TEST_VOLUMES/generated_btcpay_datadir/_data/settings.config" || fail_test 'settings were not restored'
}

# Ordinary restores preserve SCBs outside the managed LND directory, including
# before a startup that replaces its channel.backup with an empty channel list.
for format in plain encrypted; do
  for mode in backup legacy; do
    new_case
    make_fixture "$mode" lnd
    pack_archive "$format"
    export RESTORE_TEST_REWRITE_SCB=true
    mkdir -p "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data"
    expect_success "$archive_path"
    assert_imports
    [ -f "$case_dir/running-all" ] || fail_test 'ordinary restore did not restart BTCPay'
    [ ! -d "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/data/graph" ] ||
      fail_test 'ordinary restore introduced graph data'
    shopt -s nullglob
    recovery_dirs=("$BTCPAY_BASE_DIRECTORY"/lnd-recovery.*)
    shopt -u nullglob
    [ "${#recovery_dirs[@]}" -eq 1 ] || fail_test 'SCB recovery directory was not retained'
    for network in mainnet testnet regtest; do
      cmp "$fixture_dir/volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/channel.backup" \
        "${recovery_dirs[0]}/$network/channel.backup" || fail_test 'preserved SCB changed during LND startup'
      grep -q '^empty-channel-list' "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/channel.backup" ||
        fail_test 'SCB startup rewrite simulation did not run'
    done
    grep -Fq "${recovery_dirs[0]}" "$case_dir/restore.log" || fail_test 'recovery directory was not displayed'
    grep -q 'bitcoin-lncli.sh.*verifychanbackup' "$case_dir/restore.log" || fail_test 'SCB verification guidance was not displayed'
    grep -q 'bitcoin-lncli.sh.*restorechanbackup' "$case_dir/restore.log" || fail_test 'SCB import guidance was not displayed'
    [ ! -d "$RESTORE_TEST_VOLUMES/backup_datadir/_data/restore" ] || fail_test 'temporary restore files were not cleaned up'
  done
done

# Migration preserves complete channel state and leaves even the database
# containers stopped. Exercise both supported flag positions and encryption.
for format in plain encrypted; do
  new_case
  make_fixture migrate lnd-full
  pack_archive "$format"
  if [ "$format" = plain ]; then
    expect_success --migrate "$archive_path"
  else
    expect_success "$archive_path" --migrate
  fi
  assert_imports
  assert_stopped
  diff -r "$fixture_dir/volumes/generated_lnd_bitcoin_datadir/_data" \
    "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data" || fail_test 'migration changed LND state'
  grep -q 'btcpay-up.sh' "$case_dir/restore.log" || fail_test 'migration did not explain manual startup'
done

# The two archive modes cannot silently be interchanged. Graph data in older
# unmarked archives is also unsafe for ordinary disaster recovery.
for scenario in migrate-default backup-migrate legacy-migrate legacy-graph backup-graph unknown-mode; do
  new_case
  restore_args=()
  case "$scenario" in
    migrate-default) make_fixture migrate lnd-full ;;
    backup-migrate) make_fixture backup lnd; restore_args=(--migrate) ;;
    legacy-migrate) make_fixture legacy lnd-full; restore_args=(--migrate) ;;
    legacy-graph) make_fixture legacy lnd-full ;;
    backup-graph) make_fixture backup lnd-full ;;
    unknown-mode) make_fixture invalid lnd ;;
  esac
  pack_archive
  expect_failure "${restore_args[@]}" "$archive_path"
  assert_untouched
done

# Every network needs both regular, nonempty databases, even when the other
# networks have valid pairs. Symlinks must not satisfy either requirement.
for database in data/chain/bitcoin/testnet/wallet.db data/graph/testnet/channel.db; do
  for invalid in missing empty directory symlink dangling-symlink; do
    new_case
    make_fixture migrate lnd-full
    database_path="$fixture_dir/volumes/generated_lnd_bitcoin_datadir/_data/$database"
    case "$invalid" in
      missing) rm -- "$database_path" ;;
      empty) : > "$database_path" ;;
      directory) rm -- "$database_path"; mkdir "$database_path" ;;
      symlink)
        mv -- "$database_path" "$database_path.actual"
        ln -s "$(basename "$database_path").actual" "$database_path"
        ;;
      dangling-symlink)
        rm -- "$database_path"
        ln -s missing-database "$database_path"
        ;;
    esac
    pack_archive
    expect_failure --migrate "$archive_path"
    assert_untouched
    grep -Fq "${database##*/} for Bitcoin LND testnet" "$case_dir/restore.log" ||
      fail_test "migration did not identify $invalid $database"
  done
done

# Enumerate both sides: an entire network directory may be absent rather than
# only its database. Other complete networks must not mask the incomplete one.
for network_dir in data/chain/bitcoin/testnet data/graph/testnet; do
  new_case
  make_fixture migrate lnd-full
  mv -- "$fixture_dir/volumes/generated_lnd_bitcoin_datadir/_data/$network_dir" "$case_dir/removed-network"
  pack_archive
  expect_failure --migrate "$archive_path"
  assert_untouched
  grep -Eq '(wallet|channel)\.db for Bitcoin LND testnet' "$case_dir/restore.log" ||
    fail_test "migration did not identify the missing $network_dir database"
done

# An empty network directory is incomplete state, while a node that has never
# created any network directories can still be migrated.
for network_root in data/chain/bitcoin data/graph; do
  new_case
  make_fixture migrate lnd-full
  mkdir "$fixture_dir/volumes/generated_lnd_bitcoin_datadir/_data/$network_root/signet"
  pack_archive
  expect_failure --migrate "$archive_path"
  assert_untouched
  grep -Eq '(wallet|channel)\.db for Bitcoin LND signet' "$case_dir/restore.log" ||
    fail_test "migration did not identify the empty $network_root/signet network"
done
new_case
make_fixture migrate none
fixture_file volumes/generated_lnd_bitcoin_datadir/_data/tls.cert 'uninitialized LND fixture'
pack_archive
expect_success --migrate "$archive_path"
assert_imports
assert_stopped

# Regular database files reached through linked roots or network directories
# are also unsafe. Keep the link target within the archive but outside LND's
# network roots so no unrelated extra network can cause the expected failure.
for linked_dir in data data/chain data/chain/bitcoin data/chain/bitcoin/testnet data/graph data/graph/testnet; do
  new_case
  make_fixture migrate lnd-full
  linked_path="$fixture_dir/volumes/generated_lnd_bitcoin_datadir/_data/$linked_dir"
  mv -- "$linked_path" "$fixture_dir/linked-directory-target"
  ln -s "$(realpath --relative-to="$(dirname "$linked_path")" "$fixture_dir/linked-directory-target")" "$linked_path"
  pack_archive
  expect_failure --migrate "$archive_path"
  assert_untouched
  grep -Fq 'directory (symlinks are not allowed):' "$case_dir/restore.log" &&
    grep -Fq "/$linked_dir" "$case_dir/restore.log" ||
    fail_test "migration did not identify the linked $linked_dir directory"
done

# A linked volume parent must not bypass validation, including when its target
# is missing and the nested _data path therefore appears not to exist.
for link_target in linked-volume-target missing-volume-target; do
  new_case
  make_fixture migrate lnd-full
  volume_path="$fixture_dir/volumes/generated_lnd_bitcoin_datadir"
  mv -- "$volume_path" "$fixture_dir/linked-volume-target"
  ln -s "../$link_target" "$volume_path"
  pack_archive
  expect_failure --migrate "$archive_path"
  assert_untouched
  grep -Fq 'directory (symlinks are not allowed):' "$case_dir/restore.log" &&
    grep -Fq '/volumes/generated_lnd_bitcoin_datadir' "$case_dir/restore.log" ||
    fail_test 'migration did not identify the linked LND volume'
done

# Refuse to overlay any existing LND destination data in either mode. This
# catches channel.db as well as hidden files and unrelated wallet state.
for mode in backup migrate; do
  for sentinel in data/graph/mainnet/channel.db .existing-wallet; do
    new_case
    restore_args=()
    if [ "$mode" = migrate ]; then
      make_fixture migrate lnd-full
      restore_args=(--migrate)
    else
      make_fixture backup lnd
    fi
    pack_archive
    destination_sentinel="$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/$sentinel"
    mkdir -p "$(dirname "$destination_sentinel")"
    printf 'never overwrite me\n' > "$destination_sentinel"
    expect_failure "${restore_args[@]}" "$archive_path"
    assert_untouched
    grep -q '^never overwrite me$' "$destination_sentinel" || fail_test 'existing LND data was overwritten'
  done
done

# New archives carry source secrets; refuse even an empty destination secrets
# directory before shutting down or changing any destination data.
for mode in backup migrate; do
  for existing_secrets in empty populated; do
    new_case
    restore_args=()
    if [ "$mode" = migrate ]; then
      make_fixture migrate lnd-full
      restore_args=(--migrate)
    else
      make_fixture backup lnd
    fi
    fixture_file secrets/test_password 'source secret'
    pack_archive
    mkdir "$case_dir/btcpayserver-docker/secrets"
    if [ "$existing_secrets" = populated ]; then
      printf 'destination secret\n' > "$case_dir/btcpayserver-docker/secrets/test_password"
    fi
    expect_failure "${restore_args[@]}" "$archive_path"
    assert_untouched
    grep -q 'destination secrets path already exists' "$case_dir/restore.log" ||
      fail_test 'existing secrets were not rejected explicitly'
    if [ "$existing_secrets" = populated ]; then
      grep -q '^destination secret$' "$case_dir/btcpayserver-docker/secrets/test_password" ||
        fail_test 'preflight failure overwrote destination secrets'
    fi
  done
done

# Older archives have no secrets directory and keep destination secrets intact.
new_case
make_fixture legacy lnd
pack_archive
mkdir "$case_dir/btcpayserver-docker/secrets"
printf 'destination secret\n' > "$case_dir/btcpayserver-docker/secrets/test_password"
expect_success "$archive_path"
assert_imports
grep -q '^destination secret$' "$case_dir/btcpayserver-docker/secrets/test_password" ||
  fail_test 'legacy restore changed destination secrets'

# Recheck after shutdown: LND may write final state between preflight and stop.
new_case
make_fixture backup lnd
pack_archive
export RESTORE_TEST_CREATE_LND_ON_STOP=true
expect_failure "$archive_path"
assert_stopped
grep -q '^existing destination settings$' "$RESTORE_TEST_VOLUMES/generated_btcpay_datadir/_data/settings.config" ||
  fail_test 'post-shutdown guard failed to prevent the overlay'
grep -q '^created during shutdown$' "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/sentinel" ||
  fail_test 'post-shutdown LND data was overwritten'

# Wallet-only LND backups remain usable, with a clear missing-SCB warning.
new_case
make_fixture backup lnd-no-scb
pack_archive
expect_success "$archive_path"
assert_imports
grep -qi 'channel.backup\|static channel backup' "$case_dir/restore.log" || fail_test 'missing-SCB warning was not displayed'
[ -f "$case_dir/running-all" ] || fail_test 'wallet-only restore did not restart'

# No-LND and CLN restores retain existing behavior and do not create LND
# recovery files. An unrelated destination LND volume is not overwritten.
for lightning in none cln; do
  new_case
  make_fixture backup "$lightning"
  pack_archive
  mkdir -p "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data"
  printf 'unrelated LND state\n' > "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/sentinel"
  expect_success "$archive_path"
  assert_imports
  [ -f "$case_dir/running-all" ] || fail_test "$lightning restore did not restart"
  grep -q '^unrelated LND state$' "$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data/sentinel" ||
    fail_test 'restore changed an LND volume absent from the archive'
  if [ "$lightning" = cln ]; then
    diff -r "$fixture_dir/volumes/generated_clightning_bitcoin_datadir" \
      "$RESTORE_TEST_VOLUMES/generated_clightning_bitcoin_datadir" || fail_test 'CLN data was changed'
  fi
  shopt -s nullglob
  recovery_dirs=("$BTCPAY_BASE_DIRECTORY"/lnd-recovery.*)
  shopt -u nullglob
  [ "${#recovery_dirs[@]}" -eq 0 ] || fail_test "$lightning restore created an LND recovery directory"
done

# Failures after shutdown must never restart partially restored services.
for mode in backup migrate; do
  for failure in overlay postgres mariadb; do
    new_case
    restore_args=()
    if [ "$mode" = migrate ]; then
      make_fixture migrate lnd-full
      restore_args=(--migrate)
    else
      make_fixture backup lnd
    fi
    pack_archive
    if [ "$failure" = overlay ]; then
      export RESTORE_TEST_FAIL_OVERLAY=true
    else
      export RESTORE_TEST_FAIL_IMPORT="$failure"
    fi
    expect_failure "${restore_args[@]}" "$archive_path"
    assert_stopped
  done
done

# An ordinary restore can fail after starting only some services. It must
# report failure and stop those services instead of reporting a clean restore.
new_case
make_fixture backup lnd
pack_archive
export RESTORE_TEST_FAIL_RESTART=true
expect_failure "$archive_path"
assert_imports
grep -q '^compose up --remove-orphans' "$RESTORE_TEST_COMMANDS" || fail_test 'restart failure was not exercised'
assert_stopped allow-restart

# Interrupt the isolated migration process while both databases are running.
# Its TERM handler must preserve the signal exit status and run EXIT cleanup.
new_case
make_fixture migrate lnd-full
pack_archive
export RESTORE_TEST_INTERRUPT_IMPORT=true
expect_failure --migrate "$archive_path"
[ -f "$case_dir/interrupted" ] || fail_test 'migration import interrupt was not exercised'
[ "$restore_status" -eq 143 ] || fail_test "TERM exit status was $restore_status instead of 143"
grep -q '^SELECT 42;$' "$case_dir/postgres-import.sql" || fail_test 'migration was interrupted before importing'
assert_stopped

# A failed shutdown must be observed, even though the helper historically
# masked it with a successful popd. The cleanup retry may then stop containers.
for phase in initial final; do
  new_case
  make_fixture migrate lnd-full
  pack_archive
  export RESTORE_TEST_FAIL_STOP="$phase"
  expect_failure --migrate "$archive_path"
  [ -f "$case_dir/stop-failed" ] || fail_test 'shutdown failure was not exercised'
  assert_stopped
  if [ "$phase" = initial ]; then
    grep -q '^existing destination settings$' "$RESTORE_TEST_VOLUMES/generated_btcpay_datadir/_data/settings.config" ||
      fail_test 'restore overwrote data after the initial shutdown failed'
    [ ! -f "$case_dir/postgres-import.sql" ] || fail_test 'restore imported data after the initial shutdown failed'
  else
    assert_imports
  fi
done

# Help and invalid arguments must be handled before touching Docker or data.
new_case
expect_success --help
[ ! -s "$RESTORE_TEST_COMMANDS" ] || fail_test '--help accessed Docker'
assert_untouched
make_fixture backup lnd
pack_archive
for invalid in missing unknown extra duplicate; do
  case "$invalid" in
    missing) expect_failure ;;
    unknown) expect_failure --invalid "$archive_path" ;;
    extra) expect_failure "$archive_path" "$archive_path" ;;
    duplicate) expect_failure --migrate --migrate "$archive_path" ;;
  esac
  [ ! -s "$RESTORE_TEST_COMMANDS" ] || fail_test 'invalid arguments accessed Docker'
  assert_untouched
done

# Exercise the actual producer and consumer together, not only independently
# constructed archives. Source and destination use separate isolated volumes.
for mode in backup migrate; do
  for format in plain encrypted; do
    new_case
    make_fixture migrate lnd-full
    fixture_file secrets/test_password 'roundtrip source secret'
    chmod 600 "$fixture_dir/secrets/test_password"
    command cp -a "$fixture_dir/volumes/." "$RESTORE_TEST_VOLUMES/"
    command cp -a "$fixture_dir/secrets" "$case_dir/btcpayserver-docker/secrets"
    export RESTORE_TEST_BACKUP_MODE="$mode"
    backup_args=()
    backup_basename=backup
    if [ "$mode" = migrate ]; then
      backup_args=(--migrate)
      backup_basename=backup-migrate
    fi
    if [ "$format" = encrypted ]; then
      export BTCPAY_BACKUP_PASSPHRASE=roundtrip-test-passphrase
    fi
    if ! bash "$repo_dir/btcpay-backup.sh" "${backup_args[@]}" > "$case_dir/backup.log" 2>&1; then
      sed -n '1,200p' "$case_dir/backup.log" >&2
      fail_test "roundtrip backup failed ($mode, $format)"
    fi
    source_case_dir="$case_dir"
    source_fixture_dir="$fixture_dir"
    source_volumes="$RESTORE_TEST_VOLUMES"
    source_archive="$source_volumes/backup_datadir/_data/$backup_basename.tar.gz"
    if [ "$format" = encrypted ]; then
      source_archive="$source_archive.gpg"
    fi
    [ -s "$source_archive" ] || fail_test 'backup did not publish the expected archive filename'
    if [ "$mode" = migrate ]; then
      assert_stopped
    else
      [ -f "$source_case_dir/running-all" ] || fail_test 'routine roundtrip backup did not restart the source'
    fi

    # Check the mode metadata and actual backup layout, including encryption,
    # before giving the original archive directly to the restore script.
    archive_inspection="$source_case_dir/archive-inspection"
    mkdir "$archive_inspection"
    if [ "$format" = encrypted ]; then
      gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 3 \
        --decrypt "$source_archive" 3<<<"$BTCPAY_BACKUP_PASSPHRASE" |
        command tar -xzf - -C "$archive_inspection"
    else
      command tar -xzf "$source_archive" -C "$archive_inspection"
    fi
    [ "$(<"$archive_inspection/btcpay-backup-mode")" = "$mode" ] || fail_test 'roundtrip archive mode was incorrect'
    cmp "$source_fixture_dir/secrets/test_password" "$archive_inspection/secrets/test_password" ||
      fail_test 'roundtrip archive lost source secrets'
    archived_lnd="$archive_inspection/volumes/generated_lnd_bitcoin_datadir/_data"
    if [ "$mode" = migrate ]; then
      diff -r "$source_volumes/generated_lnd_bitcoin_datadir/_data" "$archived_lnd" ||
        fail_test 'migration backup did not include complete LND data'
    else
      [ ! -e "$archived_lnd/data/graph" ] || fail_test 'routine roundtrip archive included graph data'
    fi

    new_case
    fixture_dir="$source_fixture_dir"
    export RESTORE_TEST_EXPECT_SECRETS="$source_fixture_dir/secrets/test_password"
    restore_args=()
    if [ "$mode" = migrate ]; then
      restore_args=(--migrate)
    else
      export RESTORE_TEST_REWRITE_SCB=true
    fi
    if [ "$format" = encrypted ]; then
      export BTCPAY_BACKUP_PASSPHRASE=roundtrip-test-passphrase
    fi
    expect_success "${restore_args[@]}" "$source_archive"
    assert_imports
    cmp "$source_fixture_dir/secrets/test_password" "$case_dir/btcpayserver-docker/secrets/test_password" ||
      fail_test 'roundtrip restore lost source secrets'
    [ "$(stat -c '%a' "$case_dir/btcpayserver-docker/secrets")" = 700 ] ||
      fail_test 'roundtrip restore did not secure the secrets directory'
    [ "$(stat -c '%a' "$case_dir/btcpayserver-docker/secrets/test_password")" = 600 ] ||
      fail_test 'roundtrip restore changed secret file permissions'
    destination_lnd="$RESTORE_TEST_VOLUMES/generated_lnd_bitcoin_datadir/_data"
    if [ "$mode" = migrate ]; then
      assert_stopped
      [ ! -e "$source_case_dir/running-all" ] && [ ! -e "$source_case_dir/running-postgres" ] &&
        [ ! -e "$source_case_dir/running-mariadb" ] || fail_test 'migration roundtrip restarted source containers'
      diff -r "$source_volumes/generated_lnd_bitcoin_datadir/_data" "$destination_lnd" ||
        fail_test 'migration roundtrip changed LND channel state'
    else
      [ -f "$source_case_dir/running-all" ] && [ -f "$case_dir/running-all" ] ||
        fail_test 'routine roundtrip did not leave both stacks running'
      [ ! -e "$destination_lnd/data/graph" ] || fail_test 'routine roundtrip restored graph data'
      shopt -s nullglob
      recovery_dirs=("$BTCPAY_BASE_DIRECTORY"/lnd-recovery.*)
      shopt -u nullglob
      [ "${#recovery_dirs[@]}" -eq 1 ] || fail_test 'roundtrip SCBs were not preserved'
      for network in mainnet testnet regtest; do
        cmp "$source_volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/wallet.db" \
          "$destination_lnd/data/chain/bitcoin/$network/wallet.db" || fail_test 'routine roundtrip changed wallet data'
        cmp "$source_volumes/generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/channel.backup" \
          "${recovery_dirs[0]}/$network/channel.backup" || fail_test 'routine roundtrip lost the source SCB'
        grep -q '^empty-channel-list' "$destination_lnd/data/chain/bitcoin/$network/channel.backup" ||
          fail_test 'roundtrip did not exercise managed SCB replacement'
      done
    fi
  done
done

printf 'Restore tests passed (SCB recovery, migration, guards, failure cleanup, and backup roundtrips).\n'
