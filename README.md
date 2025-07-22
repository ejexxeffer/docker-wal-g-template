# 🐘 PostgreSQL + MinIO + Wal-g Stack

![Docker](https://img.shields.io/badge/Docker-3.8-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue)
![MinIO](https://img.shields.io/badge/MinIO-Latest-green)

A production-ready template for PostgreSQL with automated WAL-G backups to MinIO S3 storage.

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.12+
- 2GB+ free disk space
- 1GB+ available RAM
- Docker & Docker Compose
- Bash
- PostgreSQL
- Properly configured `.env` file

---

## ⚙️ Environment Variables (from `.env`)

| Variable               | Description                          |
| ---------------------- | ------------------------------------ |
| `COMPOSE_PROJECT_NAME` | Project prefix for Docker containers |
| `DB_USER`              | PostgreSQL username                  |
| `DB_PASSWORD`          | PostgreSQL password                  |
| `DB_NAME`              | PostgreSQL database name             |
| `DB_PORT`              | PostgreSQL external port             |
| `DB_PATH`              | Path to PostgreSQL data directory    |
| `PGDATA`               | PostgreSQL internal data path        |
| `DB_VOLUME_PATH`       | Host path for DB data and dumps      |
| `S3_USER`              | MinIO root user                      |
| `S3_PASSWORD`          | MinIO root password                  |
| `S3_PREFIX`            | WAL-G S3 prefix (bucket path)        |
| `AWS_ENDPOINT`         | MinIO/S3-compatible endpoint URL     |
| `WALG_DELTA_MAX_STEPS` | WAL-G delta config                   |
| `WALG_CONFIG_PATH`     | Path in container for `.walg.json`   |
| `NETWORK_NAME`         | Docker network to join               |

---

## 🛠️ Makefile Commands

| Command                         | Description                                                                                                       |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `make`                          | Start default configuration containers with restore basic dump _(from docker/postgres/dumps)_ and configure wal-g |
| `make up`                       | Start containers and wait for PostgreSQL to be ready without restore and                                          |
| `make db-check`                 | Check PostgreSQL status via `pg_ctl status`                                                                       |
| `make db-stop`                  | Stop PostgreSQL server inside container                                                                           |
| `make db-start`                 | Start PostgreSQL server inside container                                                                          |
| `make db-clean`                 | Delete all rows from `public.employees` table                                                                     |
| `make db-stop-clean`            | Stop PostgreSQL and clean the entire data directory (⚠️ destructive)                                              |
| `make restore-dump`             | Restore a selected `.dump` file from host into the database                                                       |
| `make restore-latest-dump`      | Automatically restore the latest available `.dump`                                                                |
| `make restore-build-dump`       | Start environment and restore predefined dump                                                                     |
| `make backup-dump`              | Create a `.dump` file using `pg_dump`                                                                             |
| `make backup-push`              | Use WAL-G to push full backup to S3                                                                               |
| `make configure-walg-build`     | Generate `.walg.json` and copy it into container                                                                  |
| `make configure-walg`           | Generate `.walg.json` and copy it into container without other commands                                           |
| `make test-wal-g`               | Show WAL-G version and available backups                                                                          |
| `make show-test-data`           | Show contents of `public.employees` table                                                                         |
| `make clean`                    | Stop containers and remove volumes                                                                                |
| `make clean-all`                | Full cleanup of Docker system (⚠️ removes images, volumes, cache)                                                 |
| `make clean-cache`              | Remove dangling images and builder cache                                                                          |
| `make clean-stopped-containers` | Remove stopped/created containers                                                                                 |
| `make help`                     | Show available make commands (nicely formatted)                                                                   |

## 📁 Project Structure

.
├── docker
│ ├── postgres
│ │ ├── data/ # Mounted PostgreSQL data directory
│ │ │ └── data
│ │ ├── Dockerfile
│ │ ├── dumps # SQL dump files (\*.dump)
│ │ │ └── <your_project_name>\_1.dump
│ │ ├── init.sql # init sql for statring db, you can change it
│ │ └── postgresql.conf # pg config
| ├── .walg.json # Auto-generated WAL-G config (not tracked)
│ └── s3 # Mounted minio s3 directory
├── docker-compose.yml # Docker services definition
└── makefile # Make commands

---

## 🚀 Quick Start

### 1. Clone this repo and enter it

```bash
git clone https://github.com/ejexxeffer/docker-wal-g-template.git
cd docker-wal-g-template
```

_or ssh if you prefer:_

```bash
git clone git@github.com:ejexxeffer/docker-wal-g-template.git
cd docker-wal-g-template
```

### 2. (Optional)Copy and configure your .env or use recommend default settings

```bash
cp .env.example .env
nano .env
```

### 3. Build and start containers

```bash
make
```

### 4. (Optional)Check if it's alive

```bash
make db-check
```

## ☁️ WAL-G Integration with MinIO

This stack comes with [WAL-G](https://github.com/wal-g/wal-g) fully pre-configured to work out-of-the-box with the MinIO S3-compatible storage bundled in the environment.

### ✅ What works

- `make backup-push`: Creates a full PostgreSQL backup using WAL-G and uploads it to MinIO.
- `make test-wal-g`: Lists available backups in the MinIO bucket.
- Automatic generation and container injection of `.walg.json` configuration.

MinIO credentials, S3 endpoint, and WAL-G settings are loaded from your `.env` and injected into the container at runtime.

---

### ⚠️ Important Limitation: WAL-G Restore (PITR) Requires New Container

WAL-G **cannot be used to restore backups** (e.g., for PITR or full volume restore) **into a running PostgreSQL container** — PostgreSQL must not be running during the restore process, and WAL-G expects a clean `PGDATA` directory.

> This means: **you must create a fresh PostgreSQL container** (or stop and remove the old one) to perform a restoration using WAL-G.

> WIP: restore backup and PITR to new container

## 📖 License

MIT — Feel free to use, modify, and share.
