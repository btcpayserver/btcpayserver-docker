#!/usr/bin/env bash
set -Eeo pipefail
shopt -s extglob

CURRENT_PGVERSION=""
EXPECTED_PGVERSION="$PG_MAJOR"
if [[ -f "/var/lib/postgresql/data/PG_VERSION" ]]; then
    CURRENT_PGVERSION="$(cat /var/lib/postgresql/data/PG_VERSION)"
fi

if [[ "$CURRENT_PGVERSION" != "$EXPECTED_PGVERSION" ]] && \
   [[ "$CURRENT_PGVERSION" != "" ]]; then
   sed -i "s/$/ $CURRENT_PGVERSION/" /etc/apt/sources.list.d/pgdg.list
   apt-get update && apt-get install -y --no-install-recommends \
		postgresql-$CURRENT_PGVERSION \
		postgresql-contrib-$CURRENT_PGVERSION \
	&& rm -rf /var/lib/apt/lists/*

    export PGBINOLD="/usr/lib/postgresql/$CURRENT_PGVERSION/bin"
    export PGDATABASE="/var/lib/postgresql/data"
    export PGDATAOLD="/var/lib/postgresql/data/$CURRENT_PGVERSION"
    export PGDATANEW="/var/lib/postgresql/data/$EXPECTED_PGVERSION"

    mkdir -p "$PGDATANEW" "$PGDATAOLD"
    find "$PGDATABASE" -maxdepth 1 -mindepth 1 \
                      -not -wholename "$PGDATAOLD" \
                      -not -wholename "$PGDATANEW" \
                      -exec mv {} "$PGDATAOLD/" \;
    
    chmod 700 "$PGDATAOLD" "$PGDATANEW"
    chown postgres .
	chown -R postgres "$PGDATAOLD" "$PGDATANEW" "$PGDATABASE"
	if [ ! -s "$PGDATANEW/PG_VERSION" ]; then
		PGDATA="$PGDATANEW" eval "gosu postgres initdb $POSTGRES_INITDB_ARGS"
	fi

    gosu postgres pg_upgrade
    rm $PGDATANEW/*.conf
    mv $PGDATANEW/* "$PGDATABASE"
    mv $PGDATAOLD/*.conf "$PGDATABASE"
    rm -r "$PGDATANEW"
    ./delete_old_cluster.sh
    rm ./analyze_new_cluster.sh
fi

if [ -f "docker-entrypoint.sh" ]; then
    exec ./docker-entrypoint.sh  "$@"
else
    exec docker-entrypoint.sh  "$@"
fi