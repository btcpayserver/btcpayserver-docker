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
migrate=false
backup_path=""
lnd_archive_dir=""
lnd_recovery_dir=""
lnd_recovery_networks=()

fail() {
  printf "\n🚨 %s\n" "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: btcpay-restore.sh [--migrate] /path/to/backup.tar.gz[.gpg]\n\n'
  printf 'Default: restore a routine backup; Bitcoin LND channels require manual channel.backup import.\n'
  printf -- '--migrate: restore an archive made with btcpay-backup.sh --migrate and leave all BTCPay containers stopped.\n'
  printf 'Use migration mode only if the source has remained stopped since the backup.\n'
}

# Run in the Compose environment directory, and return the actual down status.
# btcpay_down also runs popd, which can mask a failed shutdown.
stop_btcpay() (
  cd "$(dirname "$BTCPAY_ENV_FILE")" || exit 1
  docker-compose -f "$BTCPAY_DOCKER_COMPOSE" down -t "${COMPOSE_HTTP_TIMEOUT:-180}"
)

check_lnd_destination() {
  local target="$volumes_dir/generated_lnd_bitcoin_datadir/_data"
  local entries

  if [ -z "$lnd_archive_dir" ]; then
    return 0
  fi
  if [ -L "$(dirname "$target")" ] || [ -L "$target" ] ||
      { [ -e "$target" ] && [ ! -d "$target" ]; }; then
    fail "The destination Bitcoin LND data directory is not a regular directory."
  fi

  shopt -s dotglob nullglob
  entries=("$target"/*)
  shopt -u dotglob nullglob
  if [ "${#entries[@]}" -ne 0 ]; then
    fail "The destination Bitcoin LND data directory is not empty. Use a fresh LND destination; restoring over existing wallet or channel data is unsafe. See docs/backup-restore.md."
  fi
}

preserve_lnd_backups() {
  local scb network
  local scb_files

  shopt -s nullglob
  scb_files=("$lnd_archive_dir"/data/chain/bitcoin/*/channel.backup)
  shopt -u nullglob
  for scb in "${scb_files[@]}"; do
    if [ -L "$scb" ] || [ ! -f "$scb" ]; then
      fail "The archived LND static channel backup is not a regular file: $scb"
    fi
    if [ ! -s "$scb" ]; then
      continue
    fi
    network=$(basename "$(dirname "$scb")")
    if ! [[ "$network" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      fail "Unexpected Bitcoin LND network directory: $network"
    fi
    if [ -z "$lnd_recovery_dir" ]; then
      if ! lnd_recovery_dir=$(mktemp -d "$BTCPAY_BASE_DIRECTORY/lnd-recovery.XXXXXX"); then
        fail "Could not create a directory to preserve LND static channel backups."
      fi
    fi
    if ! mkdir -- "$lnd_recovery_dir/$network" ||
        ! cp -- "$scb" "$lnd_recovery_dir/$network/channel.backup"; then
      fail "Could not preserve the LND static channel backup for $network."
    fi
    lnd_recovery_networks+=("$network")
  done
  if [ -n "$lnd_recovery_dir" ]; then
    printf 'ℹ️ LND static channel backups preserved in %s. Keep this directory until recovery is complete.\n' "$lnd_recovery_dir"
  fi
}

print_lnd_recovery_steps() {
  local network

  printf '\n⚠️ Bitcoin LND channel recovery is NOT automatic. Restoring the wallet does not restore open channels.\n'
  if [ "${#lnd_recovery_networks[@]}" -eq 0 ]; then
    printf '⚠️ No nonempty channel.backup was found. Wallet data was restored, but channel recovery needs a separately saved SCB.\n'
    printf 'See docs/backup-restore.md and LND\047s disaster recovery documentation.\n'
    return
  fi
  printf 'Keep the original node stopped. Once LND is unlocked and synced, verify the preserved SCB for your network.\n'
  printf 'Use only the commands for the network configured on the destination; --network does not reconfigure LND.\n'
  printf 'Only after verification succeeds, run restorechanbackup: it asks peers to FORCE-CLOSE the backed-up channels.\n'
  printf 'Import channel.backup, never channel.db. Recovery depends on peers responding. See docs/backup-restore.md.\n'
  for network in "${lnd_recovery_networks[@]}"; do
    printf '\nCommands for %s (paths used by bitcoin-lncli.sh are inside the container):\n' "$network"
    printf '  ./bitcoin-lncli.sh --network=%q getinfo\n' "$network"
    printf '  docker cp %q btcpayserver_lnd_bitcoin:/data/recovery-channel.backup\n' "$lnd_recovery_dir/$network/channel.backup"
    printf '  ./bitcoin-lncli.sh --network=%q verifychanbackup --multi_file=/data/recovery-channel.backup\n' "$network"
    printf '  ./bitcoin-lncli.sh --network=%q restorechanbackup --multi_file=/data/recovery-channel.backup\n' "$network"
  done
}

cleanup_on_exit() {
  local status=$?

  trap - EXIT

  if [ "$status" -ne 0 ]; then
    if [ "$btcpay_stopped" = true ] && [ -n "${BTCPAY_DOCKER_COMPOSE:-}" ]; then
      printf "\nℹ️ Stopping containers after the failed restore …\n" >&2
      if stop_btcpay >/dev/null 2>&1; then
        printf "ℹ️ BTCPay Server has been left stopped to avoid using partially restored data.\n" >&2
      else
        printf "⚠️ Containers could not be stopped automatically. Run btcpay-down.sh before continuing.\n" >&2
      fi
    fi

    if [ -n "$restore_dir" ] && [ -d "$restore_dir" ]; then
      printf "ℹ️ Restore files were retained in %s for diagnosis.\n" "$restore_dir" >&2
    fi
    if [ -n "$lnd_recovery_dir" ]; then
      printf 'ℹ️ Preserved LND static channel backups remain in %s.\n' "$lnd_recovery_dir" >&2
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
trap 'exit 130' INT
trap 'exit 143' TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --migrate)
      if [ "$migrate" = true ]; then
        fail "--migrate was specified more than once."
      fi
      migrate=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if [ "$#" -ne 1 ] || [ -n "$backup_path" ]; then
        fail "Specify exactly one backup archive."
      fi
      backup_path=$1
      shift
      ;;
    -*)
      fail "Unknown option: $1. Use --help for usage."
      ;;
    *)
      if [ -n "$backup_path" ]; then
        fail "Specify exactly one backup archive."
      fi
      backup_path=$1
      shift
      ;;
  esac
done

if [ -z "$backup_path" ]; then
  usage >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  printf "\n🚨 This script must be run as root.\n"
  printf "➡️ Use the command 'sudo su -' (include the trailing hyphen) and try again.\n\n"
  exit 1
fi

if [ ! -f "$backup_path" ]; then
  fail "$backup_path does not exist."
fi

# Load the BTCPay environment when the caller has not already done so.
if [ -f "/etc/profile.d/btcpay-env.sh" ]; then
  # shellcheck source=/dev/null
  . "/etc/profile.d/btcpay-env.sh"
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
  printf "\nℹ️ Set BTCPAY_BACKUP_PASSPHRASE to the archive's passphrase and retry the same command.\n\n"
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
if [ -L "secrets" ]; then
  fail "The backup secrets directory must not be a symlink."
fi
if [ -e "secrets" ] && [ ! -d "secrets" ]; then
  fail "The backup secrets path is not a directory."
fi
if [ -d "secrets" ] && [ -n "$(find "secrets" -type l -print -quit)" ]; then
  fail "The backup secrets directory must not contain symlinks."
fi
if [ -d "secrets" ] && { [ -e "$btcpay_dir/secrets" ] || [ -L "$btcpay_dir/secrets" ]; }; then
  fail "The destination secrets path already exists. Remove it before restoring this backup."
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

archive_mode=legacy
if [ -e btcpay-backup-mode ] || [ -L btcpay-backup-mode ]; then
  if [ -L btcpay-backup-mode ] || [ ! -f btcpay-backup-mode ]; then
    fail "The backup mode marker is not a regular file."
  fi
  archive_mode=$(<btcpay-backup-mode)
  case "$archive_mode" in
    backup|migrate) ;;
    *) fail "The backup contains an invalid mode marker." ;;
  esac
fi
if [ "$migrate" = true ]; then
  if [ "$archive_mode" != migrate ]; then
    fail "--migrate requires an archive created by btcpay-backup.sh --migrate. Routine and legacy archives cannot be used for migration."
  fi
  printf '\n⚠️ Migration restore: the source must have remained stopped since this archive was created.\n'
  printf 'The destination stack will also remain stopped until you start it explicitly.\n'
elif [ "$archive_mode" = migrate ]; then
  fail "This is a migration archive. Use --migrate only if the source has remained stopped since backup. For an outdated archive, follow the SCB disaster recovery instructions in docs/backup-restore.md."
fi

archived_lnd_data="$restore_dir/volumes/generated_lnd_bitcoin_datadir/_data"
if [ "$migrate" = true ]; then
  # Check ancestors before looking for databases so symlinks cannot redirect
  # validation outside the archived LND data or hide unmatched network state.
  for directory in \
    "$restore_dir/volumes" \
    "$restore_dir/volumes/generated_lnd_bitcoin_datadir" \
    "$archived_lnd_data" \
    "$archived_lnd_data/data" \
    "$archived_lnd_data/data/chain" \
    "$archived_lnd_data/data/chain/bitcoin" \
    "$archived_lnd_data/data/graph"; do
    if [ -L "$directory" ] || { [ -e "$directory" ] && [ ! -d "$directory" ]; }; then
      fail "The migration archive has an invalid Bitcoin LND directory (symlinks are not allowed): $directory"
    fi
  done
fi
if [ -e "$archived_lnd_data" ] || [ -L "$archived_lnd_data" ]; then
  if [ -L "$archived_lnd_data" ] || [ ! -d "$archived_lnd_data" ]; then
    fail "The archived Bitcoin LND data directory is not a regular directory."
  fi
  lnd_archive_dir="$archived_lnd_data"
  if [ "$migrate" = false ]; then
    if [ -e "$lnd_archive_dir/data/graph" ] || [ -L "$lnd_archive_dir/data/graph" ]; then
      fail "This archive contains Bitcoin LND channel state. Refusing to start a potentially outdated channel database. Follow the SCB disaster recovery instructions in docs/backup-restore.md."
    fi
    printf '\n⚠️ This restore recovers the Bitcoin LND wallet only. Manual channel.backup import is required to recover channel funds by asking peers to force-close.\n'
  else
    # Inspect both sides of every network pair, including directories whose
    # database is missing. A graph-only network must not escape validation.
    shopt -s dotglob nullglob
    lnd_network_dirs=("$lnd_archive_dir"/data/chain/bitcoin/* "$lnd_archive_dir"/data/graph/*)
    shopt -u dotglob nullglob
    for directory in "${lnd_network_dirs[@]}"; do
      if [ -L "$directory" ] || [ ! -d "$directory" ]; then
        fail "The migration archive has an invalid Bitcoin LND network directory (symlinks are not allowed): $directory"
      fi
      network=${directory##*/}
      for database in \
        "$lnd_archive_dir/data/chain/bitcoin/$network/wallet.db" \
        "$lnd_archive_dir/data/graph/$network/channel.db"; do
        if [ -L "$database" ] || [ ! -f "$database" ] || [ ! -s "$database" ]; then
          fail "The migration archive has missing or invalid ${database##*/} for Bitcoin LND $network. Each network requires a nonempty regular wallet.db/channel.db pair without symlinks."
        fi
      done
    done
  fi
  check_lnd_destination
fi

cd "$btcpay_dir"
# shellcheck source=/dev/null
. ./helpers.sh

printf "\nℹ️ Stopping BTCPay Server …\n\n"
btcpay_stopped=true
if ! stop_btcpay; then
  fail "Could not stop the BTCPay containers. No volumes have been restored."
fi

# Recheck after shutdown in case the destination created LND data during
# validation. An overlay must never mix different wallets or channel states.
check_lnd_destination
if [ -n "$lnd_archive_dir" ] && [ "$migrate" = false ]; then
  preserve_lnd_backups
fi

cd "$restore_dir"

if [ -d "secrets" ]; then
  printf "\nℹ️ Restoring secrets …\n"
  if [ -e "$btcpay_dir/secrets" ] || [ -L "$btcpay_dir/secrets" ]; then
    fail "The destination secrets path already exists. Remove it before restoring this backup."
  fi
  if ! mkdir -m 700 -- "$btcpay_dir/secrets" ||
      ! cp -a -- "secrets/." "$btcpay_dir/secrets/" ||
      ! chmod 700 -- "$btcpay_dir/secrets"; then
    fail "Restoring secrets failed. Please check the error above."
  fi
  printf "✅ Secret restore done.\n"
fi

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
if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up --no-deps -d postgres; then
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
  if ! docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up --no-deps -d mariadb; then
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

if [ "$migrate" = true ]; then
  printf '\nℹ️ Stopping database containers after migration restore …\n\n'
  if ! stop_btcpay; then
    fail "Could not stop the BTCPay containers after migration restore."
  fi
else
  printf "\nℹ️ Restarting BTCPay Server …\n\n"
  cd "$btcpay_dir"
  btcpay_up
  btcpay_stopped=false
fi

printf "\nℹ️ Cleaning up …\n\n"
if [ "$restore_dir" != "$expected_restore_dir" ] || [ -z "$restore_dir" ]; then
  fail "Refusing to clean an unexpected restore directory."
fi
if ! rm -rf -- "$restore_dir"; then
  fail "Could not clean restore directory $restore_dir."
fi

if [ "$migrate" = true ]; then
  printf '✅ Migration restore done. All BTCPay containers remain stopped.\n'
  printf 'Keep the source stopped permanently. After verifying the destination configuration, start it with ./btcpay-up.sh from the BTCPay Docker directory.\n\n'
else
  printf "✅ Restore done\n\n"
  if [ -n "$lnd_archive_dir" ]; then
    print_lnd_recovery_steps
  fi
fi
