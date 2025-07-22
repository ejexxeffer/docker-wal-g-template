# Makefile
include .env
export

# this is need for volumes backup im didn't done it yet
BACKUP_DIR := backup_${COMPOSE_PROJECT_NAME}_volumes

DUMP_FILE := ${DB_VOLUME_PATH}/dumps/${DB_NAME}_1.dump
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

.PHONY: all up restore-build-dump restore-dump restore-latest-dump backup-dump clean clean-all help clean-cache clean-stopped-containers configure-walg-build configure-walg test-wal-g backup-push show-test-data clean-db db-check

all: configure-walg-build

up:
	@echo "Using DB_USER from .env: [${DB_USER}]"
	@echo "Using DB_NAME from .env: [${DB_NAME}]"
	@echo "Creating network if needed..."
	@docker network create ${NETWORK_NAME} || true
	@echo "Starting containers..."
	@docker compose up -d
	@echo "Waiting for PostgreSQL to become ready..."
	@while ! docker exec ${COMPOSE_PROJECT_NAME}_postgres pg_isready -U $(DB_USER) -d $(DB_NAME); do \
		sleep 1; \
		echo "Retrying connection..."; \
	done
	sleep 2
	@echo "PostgreSQL is ready! ✅"

restore-build-dump: up
	@echo "Restoring database dump..."
	@test -f $(DUMP_FILE) || (echo "Error: Dump file $(DUMP_FILE) not found ❌"; exit 1)
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres psql -U $(DB_USER) -d $(DB_NAME) < $(DUMP_FILE)
	@echo "Restore completed successfully! ✅"

restore-dump:
	@echo "Available database dumps in $(DUMP_DIR):"
	@ls -lt $(DUMP_DIR)/*.dump 2>/dev/null | head -n 5 || echo "No .dump files found"
	@read -p "Enter filename (or press Enter for most recent ${DB_NAME}_*.dump): " DUMP_CHOICE; \
	if [ -z "$$DUMP_CHOICE" ]; then \
		DUMP_FILE=$$(ls -t $(DUMP_DIR)/${DB_NAME}_*.dump 2>/dev/null | head -n 1); \
		if [ -z "$$DUMP_FILE" ]; then \
			echo "Error: No ${DB_NAME}_*.dump files found ❌"; exit 1; \
		fi; \
		echo "Using latest dump: $$DUMP_FILE"; \
	else \
		DUMP_FILE="$(DUMP_DIR)/$$DUMP_CHOICE"; \
		if [ ! -f "$$DUMP_FILE" ]; then \
			echo "Error: File $$DUMP_FILE not found ❌"; exit 1; \
		fi; \
	fi; \
	echo "Restoring $$DUMP_FILE to ${DB_NAME}..."; \
	docker exec -i ${COMPOSE_PROJECT_NAME}_postgres psql -U $(DB_USER) -d $(DB_NAME) < $$DUMP_FILE
	@echo "Restore completed! ✅"

restore-latest-dump:
	@DUMP_FILE=$$(ls -t $(DUMP_DIR)/${DB_NAME}_*.dump 2>/dev/null | head -n 1); \
	if [ -z "$$DUMP_FILE" ]; then \
		echo "Error: No ${DB_NAME}_*.dump files found in $(DUMP_DIR) ❌"; exit 1; \
	fi; \
	echo "Restoring latest: $$DUMP_FILE"; \
	docker exec -i ${COMPOSE_PROJECT_NAME}_postgres psql -U $(DB_USER) -d $(DB_NAME) < $$DUMP_FILE
	@echo "Restore completed! ✅"

backup-dump:
	@echo "Start to making dump..."
	@docker exec -i $(COMPOSE_PROJECT_NAME)_postgres pg_dump -U ${DB_USER} -d $(DB_NAME)> ./$(DUMP_DIR)/$(DB_NAME)_$(TIMESTAMP).dump
	@echo "Dump $(DB_NAME)_$(TIMESTAMP).dump was created..."

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

help:
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

clean-cache:
	@docker rmi $(docker images -a --filter=dangling=true -q)
	@docker builder prune --all

clean-stopped-containers:
	@docker rm $(docker ps --filter=status=exited --filter=status=created -q)

configure-walg-build: restore-build-dump
	@echo "Configuring WAL-G..."
	@echo "$$WALG_JSON" > ./docker/postgres/.walg.json
		sleep 1
	@docker cp ./docker/postgres/.walg.json ${COMPOSE_PROJECT_NAME}_postgres:$(WALG_CONFIG_PATH)
	@echo "WAL-G configuration updated"

configure-walg:
	@echo "Configuring WAL-G..."
	@echo "$$WALG_JSON" > ./docker/postgres/.walg.json
		sleep 1
	@docker cp ./docker/postgres/.walg.json ${COMPOSE_PROJECT_NAME}_postgres:$(WALG_CONFIG_PATH)
	@echo "WAL-G configuration updated"

test-wal-g:
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres which wal-g
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres wal-g --version
	@docker exec -i ${COMPOSE_PROJECT_NAME}_postgres wal-g backup-list

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
	@docker exec -u postgres ${COMPOSE_PROJECT_NAME}_postgres pg_ctl status -D ${DB_PATH}