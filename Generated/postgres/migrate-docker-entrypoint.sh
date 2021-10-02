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
   if ! apt-get update; then
    echo "apt-get update failed. Are you using raspberry pi 4? If yes, please follow https://blog.samcater.com/fix-workaround-rpi4-docker-libseccomp2-docker-20/"
    exit 1
   fi
   if ! apt-get install -y --no-install-recommends \
        postgresql-$CURRENT_PGVERSION \
        postgresql-contrib-$CURRENT_PGVERSION; then
        # On arm32, postgres doesn't ship those packages, so we download
        # the binaries from an archive we built from the postgres 9.6.20 image's binaries
        FALLBACK="https://aois.blob.core.windows.net/public/$CURRENT_PGVERSION-$(uname -m).tar.gz"
        FALLBACK_SHARE="https://aois.blob.core.windows.net/public/share-$CURRENT_PGVERSION-$(uname -m).tar.gz"
        echo "Failure to install postgresql-$CURRENT_PGVERSION and postgresql-contrib-$CURRENT_PGVERSION trying fallback $FALLBACK"
        apt-get install -y wget
        pushd . > /dev/null
        cd /usr/lib/postgresql
        wget $FALLBACK
        tar -xvf *.tar.gz
        rm -f *.tar.gz
        cd /usr/share/postgresql
        wget $FALLBACK_SHARE
        tar -xvf *.tar.gz
        rm -f *.tar.gz
        popd > /dev/null
        echo "Successfully installed PG utilities via the fallback"
   fi

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