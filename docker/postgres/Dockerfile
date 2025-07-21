# Stage 1: Build WAL-G from latest main
FROM golang:1.24-alpine3.22 AS builder

ENV WALG_VERSION=v3.0.7 \
  USE_BROTLI=1 \
  USE_LIBSODIUM=1 \
  USE_LZO=1

# Install build dependencies
RUN apk add --no-cache \
  git \
  make \
  cmake \
  bash \
  wget \
  curl \
  build-base \
  libsodium-dev \
  lzo \
  lzo-dev

# Explicit path
RUN git clone --depth 1 https://github.com/wal-g/wal-g /usr/src/wal-g

# Build WAL-G
WORKDIR /usr/src/wal-g

RUN export USE_BROTLI=${USE_BROTLI} && \
  export USE_LIBSODIUM=${USE_LIBSODIUM} && \
  export USE_LZO=${USE_LZO}

# RUN git checkout $WALG_VERSION
RUN make deps \
  && make pg_build \
  && make pg_install

# Stage 2: PostgreSQL Runtime
FROM postgres:14-alpine3.20

# Runtime dependencies
RUN apk add --no-cache \
  brotli \
  lz4 \
  lzo \
  curl \
  libsodium \
  libc6-compat \
  ca-certificates

# Copy built binary
# COPY --from=builder /usr/src/wal-g /usr/local/bin/wal-g
COPY --from=builder /wal-g /usr/local/bin


COPY ./init.sql /docker-entrypoint-initdb.d/001.sql
COPY ./postgresql.conf /etc/postgresql/postgresql.conf

# RUN apk add --no-cache \
#   brotli \
#   lzo \
#   gomplate \
#   libsodium \
#   lz4 \
#   libc6-compat \
#   ca-certificates

# # Verify version (outputs to logs)
RUN echo "Using WAL-G version:" && \
  wal-g --version && \
  wal-g --version > /WALG_VERSION

# Environment variables
ENV WALG_DISABLE_REDUNDANT_TARS="true" \
  WALG_COMPRESSION_METHOD="brotli" \
  WALG_UPLOAD_CONCURRENCY=1 \
  WALG_UPLOAD_QUEUE=1 \
  WALG_TAR_SIZE_THRESHOLD=536870912

# RUN chown postgres: /var/lib/postgresql/.walg.json \
#   && chmod 600

# Configure PostgreSQL
# RUN mkdir -p /etc/postgresql/ \
#   && cp /usr/local/share/postgresql/postgresql.conf.sample /etc/postgresql/postgresql.conf.tmpl

# RUN mkdir -p /etc/postgresql/ \
#   && cp /usr/local/share/postgresql/postgresql.conf.sample /etc/postgresql/postgresql.conf.tmpl \
#   && sed -ri "s/^#archive_mode = off/archive_mode = {{.Env.ARCHIVE_MODE}}/" /etc/postgresql/postgresql.conf.tmpl \
#   && sed -ri "s/^#archive_timeout = 0/archive_timeout = {{.Env.ARCHIVE_TIMEOUT}}/" /etc/postgresql/postgresql.conf.tmpl \
#   && sed -ri "s/^#archive_command = ''/archive_command = '\/wal-g wal-push %p'/" /etc/postgresql/postgresql.conf.tmpl \
#   && sed -ri "s/^#restore_command = ''/restore_command = '\/wal-g wal-fetch %f %p'/" /etc/postgresql/postgresql.conf.tmpl

# RUN echo "wal_level = replica" >> /usr/share/postgresql/postgresql.conf.sample \
#   && echo "archive_mode = on" >> /usr/share/postgresql/postgresql.conf.sample \
#   && echo "archive_command = 'wal-g wal-push %p'" >> /usr/share/postgresql/postgresql.conf.sample \
#   && echo "archive_timeout = 300" >> /usr/share/postgresql/postgresql.conf.sample

# CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
# ADD docker-entrypoint.sh /docker-entrypoint.sh
# RUN chmod u+x /docker-entrypoint.sh

# ENTRYPOINT ["/docker-entrypoint.sh"]

# ENV PGHOST=/var/run/postgresql \
#     PGUSER=postgres \
#     POSTGRES_PASSWORD=password \
#     ARCHIVE_MODE=off \
#     ARCHIVE_TIMEOUT=0 \
#     AWS_S3_FORCE_PATH_STYLE=true \
#     WALG_COMPRESSION_METHOD=brotli