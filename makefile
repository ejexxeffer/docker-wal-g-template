# Makefile
include .env
export

# this is need for volumes backup im didn't done it yet
BACKUP_DIR := backup_${COMPOSE_PROJECT_NAME}_volumes

DUMP_FILE := ${DB_VOLUME_PATH}/dumps/xefferia.dump
DUMP_DIR := ${DB_VOLUME_PATH}/dumps
TIMESTAMP := $(shell date +%Y%m%d)

define WALG_JSON
{
  "WALG_S3_PREFIX": "$(S3_PREFIX)",
  "AWS_ENDPOINT": "$(AWS_ENDPOINT)",
  "AWS_S3_FORCE_PATH_STYLE": "true",
  "AWS_REGION": "us-east-1",
  "AWS_ACCESS_KEY_ID": "$(S3_USER)",
  "AWS_SECRET_ACCESS_KEY": "$(S3_PASSWORD)",
  "WALG_COMPRESSION_METHOD": "brotli",
  "WALG_DELTA_MAX_STEPS": "$(WALG_DELTA_MAX_STEPS)",
  "PGUSER":"$(DB_USER)",
  "PGPASSWORD":"$(DB_PASSWORD)",
  "PGDATABASE":"$(DB_NAME)",
  "PGDATA": "$(DBPATH)",
  "PGHOST": "$(PGHOST)",
  "WALG_UPLOAD_QUEUE":"1",
  "WALG_UPLOAD_CONCURRENCY":"1",
  "WALG_TAR_SIZE_THRESHOLD":"536870912",
  "WALG_LOG_LEVEL": "DEVEL",
  "S3_LOG_LEVEL": "DEVEL"
}
endef

.PHONY: all up restore-dump dump clean clean-all help backup-push cleanup-backups list-backups verify-backup restore-backup configure-walg configure-walg-one

all: configure-walg

up:
	@echo "Using DB_USER from .env: [${DB_USER}]"
	@echo "Using DB_NAME from .env: [${DB_NAME}]"
	@echo "Creating network if needed..."
	@docker network create xefferia || true
	@echo "Starting containers..."
	@docker compose up -d
	@echo "Waiting for PostgreSQL to become ready..."
	@while ! docker exec ${COMPOSE_PROJECT_NAME}_postgres pg_isready -U $(DB_USER) -d $(DB_NAME); do \
		sleep 1; \
		echo "Retrying connection..."; \
	done
	sleep 2
	@echo "PostgreSQL is ready!"

restore-dump: up
	@echo "Restoring database dump..."
	@test -f $(DUMP_FILE) || (echo "Error: Dump file $(DUMP_FILE) not found"; exit 1)
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres psql -U $(DB_USER) -d $(DB_NAME) < $(DUMP_FILE)
	@echo "Restore completed successfully!"

restore-dump-once:
	@echo "Restoring database dump..."
	@test -f $(DUMP_FILE) || (echo "Error: Dump file $(DUMP_FILE) not found"; exit 1)
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres psql -U $(DB_USER) -d $(DB_NAME) < $(DUMP_FILE)
	@echo "Restore completed successfully!"

configure-walg: restore-dump
	@echo "Configuring WAL-G..."
	@echo "$$WALG_JSON" > ./docker/postgres/.walg.json
		sleep 1
	@docker cp ./docker/postgres/.walg.json xefferia_postgres:$(WALG_CONFIG_PATH)
	@echo "WAL-G configuration updated"

dump:
	@echo "Start to making dump..."
	@docker exec -it ${COMPOSE_PROJECT_NAME}_postgres pg_dump -U $(PGUSER) xefferia > $(DUMP_DIR)/xefferia_$(TIMESTAMP).dump
	@echo "Dump xefferia_$(TIMESTAMP).dump was created..."

clean:
	@echo "Cleaning up..."
	@docker compose down -v
	@docker volume prune
	@rm ./docker/postgres/.walg.json

clean-all:
	@echo "Cleaning ALL space on SYSTEM starting..."
	@docker compose down -v
	@docker system prune -a
	@rm ./docker/postgres/.walg.json

backup-push:
	@echo "Pushing PostgreSQL backup using WAL-G..."
	docker exec -u postgres ${COMPOSE_PROJECT_NAME}_postgres \
		wal-g backup-push $(PGDATA)
	@echo "Backup completed successfully"

show-test-data:
	@echo "Showing test data..."
	docker exec -u postgres ${COMPOSE_PROJECT_NAME}_postgres \
		psql -U ${DB_USER} -d ${DB_NAME} -c "SELECT * FROM public.employees;"
	@echo "✅ Data shown"

clean-db:
	@echo "🧹 Cleaning all records from public.employees..."
	docker exec -u postgres ${COMPOSE_PROJECT_NAME}_postgres \
		psql -U ${DB_USER} -d ${DB_NAME} -c "DELETE FROM public.employees;"
	@echo "✅ All records deleted from public.employees."

db-check: 
	docker exec -u postgres ${COMPOSE_PROJECT_NAME}_postgres pg_ctl status -D ${DB_PATH}

backup-volume:
	@mkdir -p $(BACKUP_DIR)
	@docker run --rm \
		--volumes-from ${COMPOSE_PROJECT_NAME}_postgres \
		-v $(shell pwd)/$(BACKUP_DIR):/backup \
		ubuntu \
		tar cvf /backup/volume_backup_$(TIMESTAMP).tar -C /var/lib/postgresql/data .
	@echo "Volume backup created: $(BACKUP_DIR)/volume_backup_$(TIMESTAMP).tar"

restore-volume:
	@test -n "$(BACKUP)" || (echo "Usage: make restore-volume BACKUP=filename.tar.gz"; exit 1)
	@docker stop ${COMPOSE_PROJECT_NAME}_postgres || true
	@docker run --rm \
		-v postgres-data:/target \
		-v $(shell pwd)/$(BACKUP_DIR):/backup \
		ubuntu \
		bash -c "tar xvzf /backup/$(BACKUP) -C /target --strip 1 && chown -R $(POSTGRES_UID):$(POSTGRES_GID) /target"
	@docker start ${COMPOSE_PROJECT_NAME}_postgres
	@echo "Volume restored from $(BACKUP). Container restarted."

test-wal-g:
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres which wal-g
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres wal-g --version
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres wal-g backup-list

help:
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)