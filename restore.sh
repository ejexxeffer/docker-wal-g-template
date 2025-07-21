#!/bin/bash
# set -e

# Восстановление базы данных из дампа
# psql -U myuser -d mydatabase -f /docker-entrypoint-initdb.d/001.sql
# 
# docker exec -it postgres-xefferia pg_restore -U ennek xefferia > dumps/xefferia.sql

# docker exec -i postgres-xefferia psql -U ennek -c "CREATE DATABASE IF NOT EXISTS xefferia;"

echo "Restoring database dump..."
docker exec -i postgres-xefferia psql -U ennek -d xefferia < dumps/xefferia.dump