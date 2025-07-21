#!/bin/bash
# set -e

docker network create xefferia || true
docker-compose up -d
echo "Waiting for PostgreSQL to become ready..."
while ! docker exec postgres-xefferia pg_isready -U "ennek" -d "xefferia"; do
  sleep 0.5
  echo "Retrying connection..."
done