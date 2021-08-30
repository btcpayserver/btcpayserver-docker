#!/bin/bash
docker exec $(docker ps -a -q -f "name=postgres_1")  psql -U postgres -c "CREATE DATABASE fireflyiii"
docker exec generated_fireflyiii_1 php artisan migrate --seed
docker exec generated_fireflyiii_1 php artisan firefly-iii:upgrade-database
exit 0