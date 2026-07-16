#!/bin/bash

set -Eeuo pipefail

# Backups can contain database dumps, wallet data, and other secrets.
umask 077

# Please be aware of these important issues:
#
# - Old channel state is toxic and you can lose all your funds, if you or someone
#   else closes a channel based on the backup with old state - and the state changes
#   often! If you publish an old state (say from yesterday's backup) on chain, you
#   WILL LOSE ALL YOUR FUNDS IN A CHANNEL, because the counterparty will publish a
#   revocation key!

backup_dir=""
backup_path=""
btcpay_dir=""
btcpay_stopped=false
database_ready_timeout=""
docker_dir=""
compose_services=""
mariadb_container=""
mariadb_dump_name=""
mariadb_dump_path=""
postgres_container=""
postgres_dump_name="postgres.sql.gz"
postgres_dump_path=""
temporary_backup_path=""
work_dir=""

fail() {
  printf "\n🚨 %s\n" "$1" >&2
  exit 1
}

cleanup_temporary_files() {
  local cleanup_failed=false
  local path

  for path in "$temporary_backup_path" "$postgres_dump_path" "$mariadb_dump_path"; do
    if [ -n "$path" ] && { [ -e "$path" ] || [ -L "$path" ]; }; then
      if ! rm -f -- "$path"; then
        printf "⚠️ Could not remove temporary file %s.\n" "$path" >&2
        cleanup_failed=true
      fi
    fi
  done

  if [ -n "$work_dir" ] && [ -d "$work_dir" ]; then
    if [ -z "$backup_dir" ] ||
        [ "$(dirname "$work_dir")" != "$backup_dir" ] ||
        [[ "$(basename "$work_dir")" != .btcpay-backup.* ]]; then
      printf "⚠️ Refusing to clean unexpected temporary directory %s.\n" "$work_dir" >&2
      cleanup_failed=true
    elif ! rmdir -- "$work_dir"; then
      printf "⚠️ Could not remove temporary directory %s.\n" "$work_dir" >&2
      cleanup_failed=true
    fi
  fi

  [ "$cleanup_failed" = false ]
}

cleanup_on_exit() {
  local status=$?
  local cleanup_failed=false

  trap - EXIT

  if [ "$btcpay_stopped" = true ] && [ -n "$btcpay_dir" ]; then
    printf "\nℹ️ Restarting BTCPay Server after failed backup …\n\n" >&2
    if (cd "$btcpay_dir" && btcpay_up); then
      btcpay_stopped=false
    else
      printf "⚠️ BTCPay Server could not be restarted automatically. Run btcpay-up.sh before continuing.\n" >&2
      cleanup_failed=true
    fi
  fi

  if ! cleanup_temporary_files; then
    cleanup_failed=true
  fi

  if [ "$status" -eq 0 ] && [ "$cleanup_failed" = true ]; then
    status=1
  fi

  exit "$status"
}

wait_for_postgres() {
  local container=$1
  local elapsed

  for ((elapsed = 0; elapsed < database_ready_timeout; elapsed++)); do
    if docker exec "$container" pg_isready --quiet --username=postgres >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

wait_for_mariadb() {
  local container=$1
  local elapsed

  for ((elapsed = 0; elapsed < database_ready_timeout; elapsed++)); do
    if docker exec "$container" mysqladmin --user=root --password=wordpressdb --silent ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

get_compose_container() {
  local service=$1
  local container

  if ! container=$(docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps -q "$service"); then
    fail "Could not inspect the $service container."
  fi
  if [[ "$container" == *$'\n'* ]]; then
    fail "Expected exactly one $service container."
  fi

  printf "%s" "$container"
}

compose_has_service() {
  local service=$1
  local configured_service

  while IFS= read -r configured_service; do
    if [ "$configured_service" = "$service" ]; then
      return 0
    fi
  done <<<"$compose_services"

  return 1
}

ensure_postgres_ready() {
  postgres_container=$(get_compose_container postgres)

  if [ -z "$postgres_container" ]; then
    printf "\nℹ️ Postgres container is not up and running. Starting it …\n\n"
    if ! docker volume create generated_postgres_datadir >/dev/null; then
      fail "Could not create the generated_postgres_datadir Docker volume."
    fi
    if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d postgres; then
      fail "Starting the Postgres database container failed."
    fi
    postgres_container=$(get_compose_container postgres)
  fi

  if [ -z "$postgres_container" ]; then
    fail "Postgres container could not be started or found."
  fi
  if ! wait_for_postgres "$postgres_container"; then
    fail "Postgres did not become ready within $database_ready_timeout seconds."
  fi
}

ensure_mariadb_ready() {
  mariadb_container=$(get_compose_container mariadb)

  if [ -z "$mariadb_container" ]; then
    printf "\nℹ️ MariaDB container is not up and running. Starting it …\n\n"
    if ! docker volume create generated_mariadb_datadir >/dev/null; then
      fail "Could not create the generated_mariadb_datadir Docker volume."
    fi
    if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d mariadb; then
      fail "Starting the MariaDB database container failed."
    fi
    mariadb_container=$(get_compose_container mariadb)
  fi

  if [ -z "$mariadb_container" ]; then
    fail "MariaDB container could not be started or found."
  fi
  if ! wait_for_mariadb "$mariadb_container"; then
    fail "MariaDB did not become ready within $database_ready_timeout seconds."
  fi
}

trap cleanup_on_exit EXIT

if [ "$(id -u)" -ne 0 ]; then
  printf "\n🚨 This script must be run as root.\n"
  printf "➡️ Use the command 'sudo su -' (include the trailing hyphen) and try again.\n\n"
  exit 1
fi

# Load the BTCPay environment when the caller has not already done so.
if [[ "${OSTYPE:-}" == darwin* ]]; then
  bash_profile_script="${HOME:?}/btcpay-env.sh"
else
  bash_profile_script="/etc/profile.d/btcpay-env.sh"
fi
if [ -f "$bash_profile_script" ]; then
  # shellcheck source=/dev/null
  . "$bash_profile_script"
fi

if [ -z "${BTCPAY_BASE_DIRECTORY:-}" ]; then
  fail "BTCPAY_BASE_DIRECTORY is not set."
fi
if [ -z "${BTCPAY_DOCKER_COMPOSE:-}" ]; then
  fail "BTCPAY_DOCKER_COMPOSE is not set."
fi
if [ -z "${BTCPAY_ENV_FILE:-}" ]; then
  fail "BTCPAY_ENV_FILE is not set."
fi
database_ready_timeout="${BTCPAY_DATABASE_READY_TIMEOUT:-60}"
if ! [[ "$database_ready_timeout" =~ ^[1-9][0-9]*$ ]]; then
  fail "BTCPAY_DATABASE_READY_TIMEOUT must be a positive number of seconds."
fi

btcpay_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
backup_passphrase="${BTCPAY_BACKUP_PASSPHRASE:-}"

if [ ! -d "$btcpay_dir" ] || [ ! -f "$btcpay_dir/helpers.sh" ]; then
  fail "BTCPay Server directory $btcpay_dir is missing or incomplete."
fi
if [ ! -f "$BTCPAY_DOCKER_COMPOSE" ]; then
  fail "Docker Compose file $BTCPAY_DOCKER_COMPOSE does not exist."
fi

if ! btcpay_mountpoint=$(docker volume inspect generated_btcpay_datadir --format='{{.Mountpoint}}'); then
  fail "Could not inspect the generated_btcpay_datadir Docker volume."
fi
if [ -z "$btcpay_mountpoint" ] || [ "$btcpay_mountpoint" = "/" ]; then
  fail "Docker returned an unsafe BTCPay volume mountpoint."
fi

btcpay_volume_dir=$(dirname "$btcpay_mountpoint")
if [ "$(basename "$btcpay_mountpoint")" != "_data" ] ||
    [ "$(basename "$btcpay_volume_dir")" != "generated_btcpay_datadir" ]; then
  fail "Docker returned an unexpected BTCPay volume mountpoint: $btcpay_mountpoint"
fi

volumes_dir=$(dirname "$btcpay_volume_dir")
if [ -z "$volumes_dir" ] || [ "$volumes_dir" = "/" ] || [ "$volumes_dir" = "." ]; then
  fail "Could not determine a safe Docker volumes directory."
fi
docker_dir=$(dirname "$volumes_dir")
if [ -z "$docker_dir" ] || [ "$docker_dir" = "/" ] || [ "$docker_dir" = "." ]; then
  fail "Could not determine a safe Docker directory."
fi

backup_dir="$volumes_dir/backup_datadir/_data"
plain_backup_path="$backup_dir/backup.tar.gz"
backup_path="$plain_backup_path"
if [ -n "$backup_passphrase" ]; then
  backup_path="$plain_backup_path.gpg"
fi

if ! mkdir -p -- "$backup_dir"; then
  fail "Could not create backup directory $backup_dir."
fi
if ! work_dir=$(mktemp -d "$backup_dir/.btcpay-backup.XXXXXX"); then
  fail "Could not create a temporary backup directory in $backup_dir."
fi
postgres_dump_path="$work_dir/$postgres_dump_name"

cd "$btcpay_dir"
# shellcheck source=/dev/null
. ./helpers.sh

if ! compose_services=$(docker-compose -f "$BTCPAY_DOCKER_COMPOSE" config --services); then
  fail "Could not inspect Docker Compose services."
fi
if ! compose_has_service postgres; then
  fail "The Docker Compose file does not define a postgres service."
fi

ensure_postgres_ready

printf "\nℹ️ Dumping Postgres database …\n"
if ! docker exec "$postgres_container" pg_dumpall -c -U postgres |
    gzip >"$postgres_dump_path"; then
  fail "Dumping Postgres database failed. Please check the error above."
fi
if ! gzip -t -- "$postgres_dump_path"; then
  fail "Postgres dump is corrupt or incomplete."
fi
printf "✅ Postgres database dump done.\n"

if compose_has_service mariadb; then
  mariadb_dump_name="mariadb.sql.gz"
  mariadb_dump_path="$work_dir/$mariadb_dump_name"
  ensure_mariadb_ready

  printf "\nℹ️ Dumping MariaDB database …\n"
  if ! docker exec "$mariadb_container" mysqldump -u root -pwordpressdb -A --add-drop-database |
      gzip >"$mariadb_dump_path"; then
    fail "Dumping MariaDB database failed. Please check the error above."
  fi
  if ! gzip -t -- "$mariadb_dump_path"; then
    fail "MariaDB dump is corrupt or incomplete."
  fi
  printf "✅ MariaDB database dump done.\n"
fi

printf "\nℹ️ Stopping BTCPay Server …\n\n"
btcpay_stopped=true
btcpay_down

cd "$docker_dir"
printf "\nℹ️ Archiving files in %s …\n" "$(pwd)"

shopt -s nullglob
volume_entries=(volumes/generated_*)
shopt -u nullglob
if [ "${#volume_entries[@]}" -eq 0 ]; then
  fail "Could not find Docker volume directories to archive."
fi

dump_entries=("$postgres_dump_name")
if [ -n "$mariadb_dump_name" ]; then
  dump_entries+=("$mariadb_dump_name")
fi

tar_excludes=(
  --exclude="volumes/backup_datadir"
  --exclude="volumes/generated_btcpay_datadir/_data/host_*"
  --exclude="volumes/generated_bitcoin_datadir/_data"
  --exclude="volumes/generated_litecoin_datadir/_data"
  --exclude="volumes/generated_mwebd_datadir"
  --exclude="volumes/generated_elements_datadir/_data"
  --exclude="volumes/generated_xmr_data/_data"
  --exclude="volumes/generated_bdx_data/_data"
  --exclude="volumes/generated_dogecoin_datadir/_data/blocks"
  --exclude="volumes/generated_dogecoin_datadir/_data/chainstate"
  --exclude="volumes/generated_dash_datadir/_data/blocks"
  --exclude="volumes/generated_dash_datadir/_data/chainstate"
  --exclude="volumes/generated_dash_datadir/_data/indexes"
  --exclude="volumes/generated_dash_datadir/_data/debug.log"
  --exclude="volumes/generated_dash_datadir/_data/evodb"
  --exclude="volumes/generated_mariadb_datadir"
  --exclude="volumes/generated_postgres_datadir"
  --exclude="volumes/generated_electrumx_datadir"
  --exclude="volumes/generated_lnd_bitcoin_datadir/_data/data/graph"
  --exclude="volumes/generated_clightning_bitcoin_datadir/_data/lightning-rpc"
  --exclude="volumes/generated_lwd-cache"
  --exclude="volumes/generated_zebrad-cache"
  --exclude="volumes/generated_zec_data"
  --exclude="**/logs/*"
)

backup_filename=$(basename "$backup_path")
if ! temporary_backup_path=$(mktemp "$backup_dir/.$backup_filename.XXXXXX"); then
  fail "Could not create a temporary archive in $backup_dir."
fi

if [ -n "$backup_passphrase" ]; then
  printf "\n🔐 BTCPAY_BACKUP_PASSPHRASE is set, the backup will be encrypted.\n"
  if ! tar -czf - "${tar_excludes[@]}" \
      -C "$work_dir" "${dump_entries[@]}" \
      -C "$docker_dir" "${volume_entries[@]}" |
      gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 \
        --symmetric --output "$temporary_backup_path" 3<<<"$backup_passphrase"; then
    fail "Archiving or encrypting failed. Please check the error above."
  fi
  if ! gpg --batch --quiet --yes --pinentry-mode loopback --passphrase-fd 3 \
      --decrypt -- "$temporary_backup_path" 3<<<"$backup_passphrase" |
      tar -tzf - >/dev/null; then
    fail "Encrypted archive validation failed."
  fi
  printf "✅ Encrypted archive done.\n"
else
  if ! tar -czf "$temporary_backup_path" "${tar_excludes[@]}" \
      -C "$work_dir" "${dump_entries[@]}" \
      -C "$docker_dir" "${volume_entries[@]}"; then
    fail "Archiving failed. Please check the error above."
  fi
  if ! tar -tzf "$temporary_backup_path" >/dev/null; then
    fail "Archive validation failed."
  fi
  printf "✅ Archive done.\n"
fi

if ! mv -f -- "$temporary_backup_path" "$backup_path"; then
  fail "Could not move the completed archive to $backup_path."
fi
temporary_backup_path=""

if [ -n "$backup_passphrase" ] && { [ -e "$plain_backup_path" ] || [ -L "$plain_backup_path" ]; }; then
  if ! rm -f -- "$plain_backup_path"; then
    fail "Could not remove the unencrypted backup archive $plain_backup_path."
  fi
fi

printf "\nℹ️ Restarting BTCPay Server …\n\n"
cd "$btcpay_dir"
btcpay_up
btcpay_stopped=false

printf "\nℹ️ Cleaning up …\n\n"
if ! cleanup_temporary_files; then
  fail "Cleanup failed."
fi
postgres_dump_path=""
mariadb_dump_path=""
work_dir=""

printf "✅ Backup done => %s\n\n" "$backup_path"
