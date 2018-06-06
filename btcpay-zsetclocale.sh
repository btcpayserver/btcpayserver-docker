#!/bin/bash

# This script is meant to fix the locale of btcpayserver database deployed in docker
# This change will make sure requests to postgres are properly using indexes when querying on text Primary keys
# You can run this if you suspect your server is very slow when you have lot's of invoices 

set -e

BTCPAY_CONTAINER_ID=$(docker ps -a -f 'name = _btcpayserver_1' -q)
POSTGRES_CONTAINER_ID=$(docker ps -a -f 'name = _postgres_1' -q)

DATABASE_NAME=$(docker inspect $BTCPAY_CONTAINER_ID | grep 'BTCPAY_POSTGRES' | sed -rn 's/.*Database=([a-z]+)",/\1/p')
PG_DUMP="docker exec $POSTGRES_CONTAINER_ID pg_dump"
PG_RESTORE="docker exec $POSTGRES_CONTAINER_ID pg_restore"
PSQL="docker exec $POSTGRES_CONTAINER_ID psql -h localhost -p 5432 -U postgres"

if [[ "$($PSQL -c "\l $DATABASE_NAME")" != *"en_US.utf8"* ]]; then
    echo "Database $DATABASE_NAME already uses locale C"
    exit 0
fi

$PG_DUMP -h localhost -p 5432 -U postgres -F c -b -v -f "/tmp/$DATABASE_NAME.backup" $DATABASE_NAME
$PSQL -c "CREATE DATABASE \"btcpayserver_new\" LC_COLLATE = 'C' TEMPLATE=template0 LC_CTYPE = 'C' ENCODING = 'UTF8'"
$PG_RESTORE -h localhost -p 5432 -U postgres -d btcpayserver_new -v "/tmp/$DATABASE_NAME.backup"
$PSQL -c "SELECT pg_terminate_backend(pid) FROM \"pg_stat_activity\" WHERE datname = '$DATABASE_NAME';"
$PSQL -c "DROP DATABASE \"$DATABASE_NAME\""
$PSQL -c "ALTER DATABASE \"btcpayserver_new\" RENAME TO \"$DATABASE_NAME\";"

echo "Database $DATABASE_NAME is now using locale C"
