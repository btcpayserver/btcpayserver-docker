#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# The production script loads this profile. Run only in an environment without
# an installed BTCPay configuration so it cannot override the test paths.
profile_path=/etc/profile.d/btcpay-env.sh
if [ -f "$profile_path" ]; then
  printf 'Run backup tests in an environment without %s.\n' "$profile_path" >&2
  exit 1
fi

test_dir="$(mktemp -d)"
cleanup() {
  gpgconf --homedir "$test_dir/gnupg" --kill gpg-agent 2>/dev/null || true
  rm -rf -- "$test_dir"
}
trap cleanup EXIT

export BTCPAY_BASE_DIRECTORY="$test_dir"
export BTCPAY_DOCKER_COMPOSE="$test_dir/compose.yml"
export BTCPAY_ENV_FILE="$test_dir/.env"
export BTCPAYGEN_REVERSEPROXY=none
export BTCPAY_DATABASE_READY_TIMEOUT=1
export COMPOSE_HTTP_TIMEOUT=180
export GNUPGHOME="$test_dir/gnupg"
export BACKUP_TEST_DOCKER_DIR="$test_dir/docker"
export BACKUP_TEST_STATE="$test_dir/state"
export BACKUP_TEST_FAILURE=""
export BACKUP_TEST_INTERRUPT=""
export BACKUP_TEST_MODE=backup
export BACKUP_TEST_MARIADB=false
export BACKUP_TEST_RUNNER_PID=$$

mkdir -p "$GNUPGHOME" "$BACKUP_TEST_STATE"
chmod 700 "$GNUPGHOME"
# Backups create and secure secrets/ in this directory. Keep it independent of
# the checkout so the real repository and its secrets are never modified.
mkdir "$test_dir/btcpayserver-docker"
cp "$repo_dir/helpers.sh" "$test_dir/btcpayserver-docker/helpers.sh"
secret_files=(test_password .hidden_password logs/test_password)
for file in "${secret_files[@]}"; do
  secret_path="$test_dir/btcpayserver-docker/secrets/$file"
  mkdir -p "$(dirname "$secret_path")"
  printf 'fixture secret: %s\n' "$file" >"$secret_path"
  chmod 600 "$secret_path"
done
touch "$BTCPAY_DOCKER_COMPOSE" "$BTCPAY_ENV_FILE"

reset_state() {
  rm -f -- "$BACKUP_TEST_STATE"/{postgres,mariadb,failure-used,interrupted}
  touch "$BACKUP_TEST_STATE/stack" "$BACKUP_TEST_STATE/postgres"
  if [ "$BACKUP_TEST_MARIADB" = true ]; then
    touch "$BACKUP_TEST_STATE/mariadb"
  fi
  printf '0\n' >"$BACKUP_TEST_STATE/stops"
  : >"$BACKUP_TEST_STATE/events"
}

# Run the actual backup script without root privileges or a Docker daemon.
# Unexpected Docker commands fail instead of reaching the host's Docker socket.
id() {
  if [ "$*" = "-u" ]; then
    printf '0\n'
  else
    command id "$@"
  fi
}

docker() {
  printf 'docker %s\n' "$*" >>"$BACKUP_TEST_STATE/events"
  case "$*" in
    'volume inspect generated_btcpay_datadir --format={{.Mountpoint}}')
      printf '%s/volumes/generated_btcpay_datadir/_data\n' "$BACKUP_TEST_DOCKER_DIR"
      ;;
    'volume create generated_postgres_datadir'|'volume create generated_mariadb_datadir')
      return 0
      ;;
    'exec postgres pg_isready --quiet --username=postgres')
      [ "$BACKUP_TEST_FAILURE" != postgres-ready ] && [ -e "$BACKUP_TEST_STATE/postgres" ]
      ;;
    'exec mariadb mysqladmin --user=root --password=wordpressdb --silent ping')
      [ "$BACKUP_TEST_FAILURE" != mariadb-ready ] && [ -e "$BACKUP_TEST_STATE/mariadb" ]
      ;;
    'exec postgres pg_dumpall -c -U postgres'|'exec mariadb mysqldump -u root -pwordpressdb -A --add-drop-database')
      if [ "$BACKUP_TEST_MODE" = migrate ] && [ -e "$BACKUP_TEST_STATE/stack" ]; then
        printf 'The application stack must stop before migration database dumps.\n' >&2
        return 1
      fi
      [ -e "$BACKUP_TEST_STATE/$2" ] || return 1
      [ "$BACKUP_TEST_FAILURE" != "$2-dump" ] || return 1
      printf '%s\n' '-- SQL test dump'
      if [ "$2" = mariadb ] && [ -n "$BACKUP_TEST_INTERRUPT" ]; then
        # The dump runs in a pipeline subshell: $$ is the isolated backup
        # process, not this subshell. Never signal the runner or process group.
        [ "$$" != "$BACKUP_TEST_RUNNER_PID" ] && [ "$BASHPID" != "$$" ] || return 1
        [ "$BACKUP_TEST_MODE" = migrate ] &&
          [ ! -e "$BACKUP_TEST_STATE/stack" ] &&
          [ -e "$BACKUP_TEST_STATE/postgres" ] &&
          [ -e "$BACKUP_TEST_STATE/mariadb" ] || return 1
        case "$BACKUP_TEST_INTERRUPT" in
          TERM|INT) ;;
          *) return 1 ;;
        esac
        touch "$BACKUP_TEST_STATE/interrupted"
        kill -s "$BACKUP_TEST_INTERRUPT" "$$"
      fi
      ;;
    *)
      printf 'Unexpected docker command: %s\n' "$*" >&2
      return 1
      ;;
  esac
}

docker-compose() {
  printf 'compose %s\n' "$*" >>"$BACKUP_TEST_STATE/events"
  [ "$1" = -f ] && [ "$2" = "$BTCPAY_DOCKER_COMPOSE" ] || return 1
  shift 2
  case "$*" in
    'config --services')
      printf 'postgres\nlnd_bitcoin\n'
      if [ "$BACKUP_TEST_MARIADB" = true ]; then
        printf 'mariadb\n'
      fi
      ;;
    'ps -q postgres'|'ps -q mariadb')
      if [ -e "$BACKUP_TEST_STATE/$3" ]; then
        printf '%s\n' "$3"
      fi
      ;;
    'up -d --no-deps postgres'|'up -d --no-deps mariadb')
      touch "$BACKUP_TEST_STATE/$4"
      [ "$BACKUP_TEST_FAILURE" != "$4-start" ]
      ;;
    'down -t 180')
      local stops
      stops=$(<"$BACKUP_TEST_STATE/stops")
      stops=$((stops + 1))
      printf '%s\n' "$stops" >"$BACKUP_TEST_STATE/stops"
      if [ "$BACKUP_TEST_FAILURE" = persistent-stop ] ||
          { [ "$BACKUP_TEST_FAILURE" = initial-stop ] && [ "$stops" -eq 1 ]; } ||
          { [ "$BACKUP_TEST_FAILURE" = archive-stop ] && [ "$stops" -eq 2 ]; }; then
        return 1
      fi
      rm -f -- "$BACKUP_TEST_STATE"/{stack,postgres,mariadb}
      ;;
    'up --remove-orphans -d -t 180')
      if [ "$BACKUP_TEST_FAILURE" = restart-once ] && [ ! -e "$BACKUP_TEST_STATE/failure-used" ]; then
        touch "$BACKUP_TEST_STATE/failure-used"
        return 1
      fi
      touch "$BACKUP_TEST_STATE/stack" "$BACKUP_TEST_STATE/postgres"
      if [ "$BACKUP_TEST_MARIADB" = true ]; then
        touch "$BACKUP_TEST_STATE/mariadb"
      fi
      ;;
    *)
      printf 'Unexpected docker-compose command: %s\n' "$*" >&2
      return 1
      ;;
  esac
}

tar() {
  if [ "$1" = -czf ]; then
    printf 'archive\n' >>"$BACKUP_TEST_STATE/events"
    if [ -e "$BACKUP_TEST_STATE/stack" ] || [ -e "$BACKUP_TEST_STATE/postgres" ] ||
        [ -e "$BACKUP_TEST_STATE/mariadb" ]; then
      printf 'All BTCPay containers must stop before archiving Lightning data.\n' >&2
      return 1
    fi
    [ "$BACKUP_TEST_FAILURE" != archive ] || return 1
  elif [ "$1" = -tzf ]; then
    printf 'validate\n' >>"$BACKUP_TEST_STATE/events"
    [ "$BACKUP_TEST_FAILURE" != validation ] || return 1
  fi
  command tar "$@"
}
export -f id docker docker-compose tar

included_files=(
  generated_btcpay_datadir/_data/settings.config
  generated_lnd_bitcoin_datadir/_data/admin.macaroon
  generated_clightning_bitcoin_datadir/_data/bitcoin/lightningd.sqlite3
  generated_clightning_bitcoin_datadir/_data/bitcoin/hsm_secret
)
graph_files=()
for network in mainnet testnet regtest; do
  graph_files+=(
    "generated_lnd_bitcoin_datadir/_data/data/graph/$network/channel.db"
    "generated_lnd_bitcoin_datadir/_data/data/graph/$network/sphinxreplay.db"
    "generated_lnd_bitcoin_datadir/_data/data/graph/$network/wtclient.db"
  )
  included_files+=(
    "generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/wallet.db"
    "generated_lnd_bitcoin_datadir/_data/data/chain/bitcoin/$network/channel.backup"
  )
done
excluded_files=(
  generated_bitcoin_datadir/_data/blocks/blk00000.dat
  generated_postgres_datadir/_data/base/test
  generated_mariadb_datadir/_data/ibdata1
  generated_electrumx_datadir/_data/cache
  generated_lnd_bitcoin_datadir/_data/logs/bitcoin/mainnet/lnd.log
  generated_clightning_bitcoin_datadir/_data/lightning-rpc
)

for file in "${included_files[@]}" "${graph_files[@]}" "${excluded_files[@]}"; do
  fixture_path="$BACKUP_TEST_DOCKER_DIR/volumes/$file"
  mkdir -p "$(dirname "$fixture_path")"
  printf '%s\n' "$file" >"$fixture_path"
done

assert_no_temporary_files() {
  local leftovers
  shopt -s nullglob
  leftovers=("$backup_dir"/.btcpay-backup.* "$backup_dir"/.backup*.tar.gz*)
  shopt -u nullglob
  [ "${#leftovers[@]}" -eq 0 ]
}

assert_stack_state() {
  if [ "$BACKUP_TEST_MODE" = migrate ]; then
    [ ! -e "$BACKUP_TEST_STATE/stack" ]
    [ ! -e "$BACKUP_TEST_STATE/postgres" ]
    [ ! -e "$BACKUP_TEST_STATE/mariadb" ]
    if grep -q 'up --remove-orphans' "$BACKUP_TEST_STATE/events"; then
      printf 'Migration must never restart the stack.\n' >&2
      exit 1
    fi
  else
    [ -e "$BACKUP_TEST_STATE/stack" ]
    [ -e "$BACKUP_TEST_STATE/postgres" ]
  fi
}

backup_dir="$BACKUP_TEST_DOCKER_DIR/volumes/backup_datadir/_data"

# Argument parsing must finish before Docker inspection or file creation.
for help_option in -h --help; do
  reset_state
  bash "$repo_dir/btcpay-backup.sh" "$help_option" >"$test_dir/help.log" 2>&1
  [ ! -s "$BACKUP_TEST_STATE/events" ]
  [ ! -d "$backup_dir" ]
done
for invalid_option in --unknown backup.tar.gz ''; do
  reset_state
  if bash "$repo_dir/btcpay-backup.sh" "$invalid_option" >"$test_dir/invalid.log" 2>&1; then
    printf 'Accepted invalid option: %s\n' "$invalid_option" >&2
    exit 1
  fi
  [ ! -s "$BACKUP_TEST_STATE/events" ]
  [ ! -d "$backup_dir" ]
done
if bash "$repo_dir/btcpay-backup.sh" --migrate extra >"$test_dir/invalid.log" 2>&1; then
  printf 'Accepted extra migration argument.\n' >&2
  exit 1
fi
[ ! -s "$BACKUP_TEST_STATE/events" ]
[ ! -d "$backup_dir" ]

for BACKUP_TEST_MODE in backup migrate; do
  backup_options=()
  backup_basename=backup
  if [ "$BACKUP_TEST_MODE" = migrate ]; then
    backup_options=(--migrate)
    backup_basename=backup-migrate
  fi
  backup_path="$backup_dir/$backup_basename.tar.gz"
  for BACKUP_TEST_MARIADB in false true; do
    for format in plain encrypted; do
      export BTCPAY_BACKUP_PASSPHRASE=""
      if [ "$format" = encrypted ]; then
        export BTCPAY_BACKUP_PASSPHRASE=backup-test-passphrase
      fi
      reset_state
      case_name="$BACKUP_TEST_MODE-$BACKUP_TEST_MARIADB-$format"
      if ! bash "$repo_dir/btcpay-backup.sh" "${backup_options[@]}" >"$test_dir/$case_name.log" 2>&1; then
        sed -n '1,200p' "$test_dir/$case_name.log" >&2
        exit 1
      fi
      assert_stack_state
      assert_no_temporary_files
      if [ "$BACKUP_TEST_MODE" = migrate ]; then
        [ "$(<"$BACKUP_TEST_STATE/stops")" -eq 2 ]
        grep -q 'all BTCPay Docker Compose containers remain stopped' "$test_dir/$case_name.log"
      else
        [ "$(<"$BACKUP_TEST_STATE/stops")" -eq 1 ]
        grep -q 'explicitly import channel.backup' "$test_dir/$case_name.log"
      fi

      restored_dir="$test_dir/restored-$case_name"
      mkdir "$restored_dir"
      if [ "$format" = encrypted ]; then
        [ ! -e "$backup_path" ]
        gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 3 \
          --decrypt "$backup_path.gpg" 3<<<"$BTCPAY_BACKUP_PASSPHRASE" |
          command tar -xzf - -C "$restored_dir"
      else
        command tar -xzf "$backup_path" -C "$restored_dir"
      fi
      printf '%s\n' "$BACKUP_TEST_MODE" >"$test_dir/expected-mode"
      cmp "$test_dir/expected-mode" "$restored_dir/btcpay-backup-mode"
      for file in "${secret_files[@]}"; do
        cmp "$test_dir/btcpayserver-docker/secrets/$file" "$restored_dir/secrets/$file"
        [ "$(stat -c '%a' "$restored_dir/secrets/$file")" = 600 ]
      done
      [ "$(stat -c '%a' "$restored_dir/secrets")" = 700 ]

      expected_files=("${included_files[@]}")
      omitted_files=("${excluded_files[@]}")
      if [ "$BACKUP_TEST_MODE" = migrate ]; then
        expected_files+=("${graph_files[@]}")
      else
        omitted_files+=("${graph_files[@]}")
        [ ! -e "$restored_dir/volumes/generated_lnd_bitcoin_datadir/_data/data/graph" ]
      fi
      for file in "${expected_files[@]}"; do
        if ! cmp "$BACKUP_TEST_DOCKER_DIR/volumes/$file" "$restored_dir/volumes/$file"; then
          printf 'Missing or changed file in %s: %s\n' "$case_name" "$file" >&2
          exit 1
        fi
      done
      for file in "${omitted_files[@]}"; do
        if [ -e "$restored_dir/volumes/$file" ]; then
          printf 'Unexpected file in %s: %s\n' "$case_name" "$file" >&2
          exit 1
        fi
      done
      gzip -t "$restored_dir/postgres.sql.gz"
      if [ "$BACKUP_TEST_MARIADB" = true ]; then
        gzip -t "$restored_dir/mariadb.sql.gz"
      else
        [ ! -e "$restored_dir/mariadb.sql.gz" ]
      fi
    done
  done

  export BACKUP_TEST_MARIADB=true
  for format in plain encrypted; do
    export BTCPAY_BACKUP_PASSPHRASE=""
    output_path="$backup_path"
    if [ "$format" = encrypted ]; then
      export BTCPAY_BACKUP_PASSPHRASE=backup-test-passphrase
      output_path="$backup_path.gpg"
    fi
    failures=(postgres-ready postgres-dump mariadb-ready mariadb-dump initial-stop archive validation)
    if [ "$BACKUP_TEST_MODE" = migrate ]; then
      failures+=(postgres-start mariadb-start archive-stop)
    fi
    for BACKUP_TEST_FAILURE in "${failures[@]}"; do
      reset_state
      printf 'previous successful backup\n' >"$output_path"
      cp "$output_path" "$test_dir/previous-backup"
      case_name="$BACKUP_TEST_MODE-$format-$BACKUP_TEST_FAILURE"
      if bash "$repo_dir/btcpay-backup.sh" "${backup_options[@]}" >"$test_dir/$case_name.log" 2>&1; then
        printf 'Backup unexpectedly succeeded for failure: %s\n' "$case_name" >&2
        exit 1
      fi
      assert_stack_state
      assert_no_temporary_files
      cmp "$test_dir/previous-backup" "$output_path"
      if [[ "$BACKUP_TEST_FAILURE" == *-stop ]] && grep -q '^archive$' "$BACKUP_TEST_STATE/events"; then
        printf 'Archived despite failed shutdown: %s\n' "$case_name" >&2
        exit 1
      fi
    done
    export BACKUP_TEST_FAILURE=""
  done
done

# Interrupt migration while both temporary database containers are running.
# Signal handlers must leave the source stopped, retain the previous archive,
# remove temporary dumps, and return the conventional signal exit status.
export BACKUP_TEST_MODE=migrate
export BACKUP_TEST_FAILURE=""
export BACKUP_TEST_MARIADB=true
for BACKUP_TEST_INTERRUPT in TERM INT; do
  expected_status=143
  if [ "$BACKUP_TEST_INTERRUPT" = INT ]; then
    expected_status=130
  fi
  for format in plain encrypted; do
    export BTCPAY_BACKUP_PASSPHRASE=""
    output_path="$backup_dir/backup-migrate.tar.gz"
    if [ "$format" = encrypted ]; then
      export BTCPAY_BACKUP_PASSPHRASE=backup-test-passphrase
      output_path="$output_path.gpg"
    fi
    reset_state
    printf 'previous successful migration backup\n' >"$output_path"
    cp "$output_path" "$test_dir/previous-backup"
    interrupt_log="$test_dir/interrupt-$BACKUP_TEST_INTERRUPT-$format.log"
    if bash "$repo_dir/btcpay-backup.sh" --migrate >"$interrupt_log" 2>&1; then
      printf 'Migration backup ignored %s.\n' "$BACKUP_TEST_INTERRUPT" >&2
      exit 1
    else
      backup_status=$?
    fi
    if [ ! -e "$BACKUP_TEST_STATE/interrupted" ] || [ "$backup_status" -ne "$expected_status" ]; then
      printf 'Migration %s interruption returned %s, expected %s.\n' \
        "$BACKUP_TEST_INTERRUPT" "$backup_status" "$expected_status" >&2
      sed -n '1,200p' "$interrupt_log" >&2
      exit 1
    fi
    assert_stack_state
    assert_no_temporary_files
    [ "$(<"$BACKUP_TEST_STATE/stops")" -eq 2 ]
    cmp "$test_dir/previous-backup" "$output_path"
    if grep -q '^archive$' "$BACKUP_TEST_STATE/events"; then
      printf 'Migration archived despite %s interruption.\n' "$BACKUP_TEST_INTERRUPT" >&2
      exit 1
    fi
  done
done
export BACKUP_TEST_INTERRUPT=""

# A failed normal restart must be reported even if exit cleanup's retry works.
export BACKUP_TEST_MODE=backup
export BACKUP_TEST_FAILURE=restart-once
export BTCPAY_BACKUP_PASSPHRASE=""
reset_state
if bash "$repo_dir/btcpay-backup.sh" >"$test_dir/restart.log" 2>&1; then
  printf 'Backup hid a failed restart.\n' >&2
  exit 1
fi
grep -q 'BTCPay Server could not be restarted after backup' "$test_dir/restart.log"
assert_stack_state
assert_no_temporary_files
command tar -tzf "$backup_dir/backup.tar.gz" >/dev/null

# If Docker keeps refusing shutdown, abort without archiving or restarting and
# explicitly tell the operator that stopping the source needs manual action.
export BACKUP_TEST_MODE=migrate
export BACKUP_TEST_FAILURE=persistent-stop
reset_state
if bash "$repo_dir/btcpay-backup.sh" --migrate >"$test_dir/shutdown.log" 2>&1; then
  printf 'Migration backup hid a persistent shutdown failure.\n' >&2
  exit 1
fi
[ "$(<"$BACKUP_TEST_STATE/stops")" -eq 2 ]
grep -q 'Could not stop all BTCPay containers. Stop the source manually' "$test_dir/shutdown.log"
if grep -Eq '^archive$|up --remove-orphans' "$BACKUP_TEST_STATE/events"; then
  printf 'Migration archived or restarted despite persistent shutdown failure.\n' >&2
  exit 1
fi
assert_no_temporary_files

printf 'Backup tests passed: both modes/formats, PostgreSQL/MariaDB, shutdown and failure cleanup.\n'
