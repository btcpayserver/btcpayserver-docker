#!/bin/bash


[[ $(docker exec $(docker ps -a -q -f "name=postgres_1")  psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'fireflyiii'") =~ "1" ]] ||  docker exec $(docker ps -a -q -f "name=postgres_1")  psql -U postgres -c "CREATE DATABASE fireflyiii"
docker exec generated_fireflyiii_1 php artisan migrate --seed
docker exec generated_fireflyiii_1 php artisan firefly-iii:decrypt-all
docker exec generated_fireflyiii_1 php artisan cache:clear
docker exec generated_fireflyiii_1 php artisan firefly-iii:upgrade-database
docker exec generated_fireflyiii_1 php artisan passport:install
docker exec generated_fireflyiii_1 php artisan cache:clear
exit 0