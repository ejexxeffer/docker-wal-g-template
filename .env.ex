# Docker example environment variables
# DB setting
COMPOSE_PROJECT_NAME=your_project_name
NETWORK_NAME=your_network_name
DB_PORT=database_port
DB_USER=database_user
DB_PASSWORD=database_password
DB_NAME=database_name
DB_VOLUME_PATH=path/to/postgres/volume
DB_PATH=/var/lib/postgresql/data/pgdata
PGHOST=/var/run/postgresql/
WALG_CONFIG_PATH=/var/lib/postgresql/.walg.json
WALG_DELTA_MAX_STEPS=5
S3_VOLUME_PATH=path/to/s3/volume
S3_PREFIX=s3://your_bucket_name/
AWS_ENDPOINT=http://minio_host:9000
S3_USER=minio_access_key
S3_PASSWORD=minio_secret_key
MINIO_OPTS="--console-address :9001"