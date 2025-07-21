#!/bin/bash
# set -e

# Восстановление базы данных из дампа
# 
# psql -U myuser -d mydatabase -f /docker-entrypoint-initdb.d/001.sql

# Making database backup
docker exec -it postgres-xefferia pg_dump -U ennek xefferia > dumps/xefferia.dump