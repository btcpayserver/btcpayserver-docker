#!/bin/bash

set -Eeuo pipefail

# Restored files can contain database dumps and other secrets.
umask 077

restore_dir=""
volumes_dir=""
btcpay_stopped=false
mariadb_dump_name=""
postgres_container=""
mariadb_container=""
database_ready_timeout=""

fail() {
  printf "\n🚨 %s\n" "$1" >&2
  exit 1
}

cleanup_on_exit() {
  local status=$?

  trap - EXIT

  if [ "$status" -ne 0 ]; then
    if [ "$btcpay_stopped" = true ] && [ -n "${BTCPAY_DOCKER_COMPOSE:-}" ]; then
      printf "\nℹ️ Stopping containers after the failed restore …\n" >&2
      if docker-compose -f "$BTCPAY_DOCKER_COMPOSE" down -t "${COMPOSE_HTTP_TIMEOUT:-180}" >/dev/null 2>&1; then
        printf "ℹ️ BTCPay Server has been left stopped to avoid using partially restored data.\n" >&2
      else
        printf "⚠️ Containers could not be stopped automatically. Run btcpay-down.sh before continuing.\n" >&2
      fi
    fi

    if [ -n "$restore_dir" ] && [ -d "$restore_dir" ]; then
      printf "ℹ️ Restore files were retained in %s for diagnosis.\n" "$restore_dir" >&2
    fi
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

# pg_dumpall --clean emits cluster-level DROP commands without IF EXISTS in
# older backups. It also tries to drop and recreate the bootstrap postgres role,
# even though the restore is connected as that role. Normalize only those
# pg_dumpall sections so all remaining SQL can safely use ON_ERROR_STOP.
normalize_postgres_dump() {
  awk '
    /^-- Drop databases/ {
      section = "drop_databases"
      print
      next
    }
    /^-- Drop tablespaces/ {
      section = "drop_tablespaces"
      print
      next
    }
    /^-- Drop roles/ {
      section = "drop_roles"
      print
      next
    }
    /^-- Roles[[:space:]]*$/ {
      section = "roles"
      print
      next
    }
    /^-- [^-]/ {
      section = ""
      print
      next
    }

    section == "drop_databases" && /^DROP DATABASE / {
      if ($0 !~ /^DROP DATABASE IF EXISTS /) {
        sub(/^DROP DATABASE /, "DROP DATABASE IF EXISTS ")
      }
      print
      next
    }
    section == "drop_tablespaces" && /^DROP TABLESPACE / {
      if ($0 !~ /^DROP TABLESPACE IF EXISTS /) {
        sub(/^DROP TABLESPACE /, "DROP TABLESPACE IF EXISTS ")
      }
      print
      next
    }
    section == "drop_roles" && /^DROP ROLE (IF EXISTS )?("postgres"|postgres);$/ {
      next
    }
    section == "drop_roles" && /^DROP ROLE / {
      if ($0 !~ /^DROP ROLE IF EXISTS /) {
        sub(/^DROP ROLE /, "DROP ROLE IF EXISTS ")
      }
      print
      next
    }
    section == "roles" && /^CREATE ROLE ("postgres"|postgres);$/ {
      next
    }

    { print }
  '
}

trap cleanup_on_exit EXIT

if [ "$(id -u)" -ne 0 ]; then
  printf "\n🚨 This script must be run as root.\n"
  printf "➡️ Use the command 'sudo su -' (include the trailing hyphen) and try again.\n\n"
  exit 1
fi

backup_path=${1:-}
if [ -z "$backup_path" ]; then
  printf "\nℹ️ Usage: btcpay-restore.sh /path/to/backup.tar.gz\n\n"
  exit 1
fi

if [ ! -f "$backup_path" ]; then
  fail "$backup_path does not exist."
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

backup_passphrase="${BTCPAY_BACKUP_PASSPHRASE:-}"
if [[ "$backup_path" == *.gpg && -z "$backup_passphrase" ]]; then
  printf "\n🔐 %s is encrypted. Please provide the passphrase to decrypt it." "$backup_path"
  printf "\nℹ️ Usage: BTCPAY_BACKUP_PASSPHRASE=t0pSeCrEt btcpay-restore.sh /path/to/backup.tar.gz.gpg\n\n"
  exit 1
fi

btcpay_dir="$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"
postgres_dump_name="postgres.sql.gz"

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

expected_restore_dir="$volumes_dir/backup_datadir/_data/restore"
restore_dir="$expected_restore_dir"
readonly expected_restore_dir

printf "\nℹ️ Cleaning restore directory %s …\n\n" "$restore_dir"
if ! rm -rf -- "$restore_dir"; then
  fail "Could not clean restore directory $restore_dir."
fi
if ! mkdir -p -- "$restore_dir"; then
  fail "Could not create restore directory $restore_dir."
fi

if [[ "$backup_path" == *.gpg ]]; then
  printf "🔐 Decrypting and extracting backup file …\n"
  if ! gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 \
      --decrypt -- "$backup_path" 3<<<"$backup_passphrase" |
      tar -xzf - -C "$restore_dir"; then
    fail "Decryption or archive extraction failed. Please check the error above."
  fi
  printf "✅ Decryption and extraction done.\n\n"
else
  printf "ℹ️ Extracting files in %s …\n" "$restore_dir"
  if ! tar -xzf "$backup_path" -C "$restore_dir"; then
    fail "Archive extraction failed. Please check the error above."
  fi
  printf "✅ Extraction done.\n\n"
fi

cd "$restore_dir"

if [ ! -f "$postgres_dump_name" ]; then
  fail "$postgres_dump_name does not exist in the backup."
fi
if [ ! -d "volumes" ]; then
  fail "The volumes directory does not exist in the backup."
fi
if ! gzip -t -- "$postgres_dump_name"; then
  fail "$postgres_dump_name is corrupt or incomplete."
fi

if [ -f "mariadb.sql.gz" ]; then
  mariadb_dump_name="mariadb.sql.gz"
  if ! gzip -t -- "$mariadb_dump_name"; then
    fail "$mariadb_dump_name is corrupt or incomplete."
  fi
fi

cd "$btcpay_dir"
# shellcheck source=/dev/null
. ./helpers.sh

printf "\nℹ️ Stopping BTCPay Server …\n\n"
btcpay_stopped=true
btcpay_down

cd "$restore_dir"

printf "\nℹ️ Restoring volumes …\n"
if ! mkdir -p -- "$volumes_dir"; then
  fail "Could not create Docker volumes directory $volumes_dir."
fi
# Overlay the backup so intentionally excluded blockchain data remains intact.
shopt -s dotglob nullglob
volume_entries=(volumes/*)
shopt -u dotglob nullglob
if [ "${#volume_entries[@]}" -eq 0 ]; then
  fail "The backup does not contain any Docker volumes."
fi
if ! cp -a -- "${volume_entries[@]}" "$volumes_dir/"; then
  fail "Restoring volumes failed. Please check the error above."
fi
if ! mkdir -p -- "$volumes_dir/generated_postgres_datadir/_data"; then
  fail "Could not create the Postgres data directory."
fi
if [ -n "$mariadb_dump_name" ] &&
    ! mkdir -p -- "$volumes_dir/generated_mariadb_datadir/_data"; then
  fail "Could not create the MariaDB data directory."
fi
printf "✅ Volume restore done.\n"

printf "\nℹ️ Starting Postgres database container …\n"
if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d postgres; then
  fail "Starting the Postgres database container failed."
fi
if ! postgres_container=$(docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps -q postgres); then
  fail "The Postgres database container could not be found."
fi
if [ -z "$postgres_container" ] || [[ "$postgres_container" == *$'\n'* ]]; then
  fail "Expected exactly one Postgres database container."
fi
if ! wait_for_postgres "$postgres_container"; then
  fail "Postgres did not become ready within $database_ready_timeout seconds."
fi

if [ -n "$mariadb_dump_name" ]; then
  printf "\nℹ️ Starting MariaDB database container …\n"
  if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d mariadb; then
    fail "Starting the MariaDB database container failed."
  fi
  if ! mariadb_container=$(docker-compose -f "$BTCPAY_DOCKER_COMPOSE" ps -q mariadb); then
    fail "The MariaDB database container could not be found."
  fi
  if [ -z "$mariadb_container" ] || [[ "$mariadb_container" == *$'\n'* ]]; then
    fail "Expected exactly one MariaDB database container."
  fi
  if ! wait_for_mariadb "$mariadb_container"; then
    fail "MariaDB did not become ready within $database_ready_timeout seconds."
  fi
fi

cd "$restore_dir"

printf "\nℹ️ Restoring Postgres database …\n"
if ! gzip -dc -- "$postgres_dump_name" |
    normalize_postgres_dump |
    docker exec -i "$postgres_container" \
      psql -X --quiet --set=ON_ERROR_STOP=1 --username=postgres --dbname=postgres >/dev/null; then
  fail "Restoring the Postgres database failed. Please check the error above."
fi
printf "✅ Postgres database restore done.\n"

if [ -n "$mariadb_dump_name" ]; then
  printf "\nℹ️ Restoring MariaDB database …\n"
  if ! gzip -dc -- "$mariadb_dump_name" |
      docker exec -i "$mariadb_container" \
        mysql --user=root --password=wordpressdb >/dev/null; then
    fail "Restoring the MariaDB database failed. Please check the error above."
  fi
  printf "✅ MariaDB database restore done.\n"
fi

printf "\nℹ️ Restarting BTCPay Server …\n\n"
cd "$btcpay_dir"
btcpay_up
btcpay_stopped=false

printf "\nℹ️ Cleaning up …\n\n"
if [ "$restore_dir" != "$expected_restore_dir" ] || [ -z "$restore_dir" ]; then
  fail "Refusing to clean an unexpected restore directory."
fi
if ! rm -rf -- "$restore_dir"; then
  fail "Could not clean restore directory $restore_dir."
fi

printf "✅ Restore done\n\n"
