#!/bin/bash
# set -e

cat > .walg.json << EOF
{
    "WALG_S3_PREFIX": "http://localhost:9001/api/v1/buckets/xefferia/",
    "AWS_ACCESS_KEY_ID": "ennekennek",
    "AWS_SECRET_ACCESS_KEY": "123412341234",
    "WALG_COMPRESSION_METHOD": "brotli",
    "WALG_DELTA_MAX_STEPS": "5",
    "PGDATA": "/var/lib/postgresql/data",
    "PGHOST": "/var/run/postgresql"
}
EOF
