#!/usr/bin/env bash
# Подготовка Dagster перед запуском `dagster dev` (webserver + daemon):
# DAGSTER_HOME, конфигурация экземпляра и metadata DB в существующем PostgreSQL.
set -euo pipefail

: "${DAGSTER_HOME:?DAGSTER_HOME is not set}"
: "${POSTGRES_HOST:?POSTGRES_HOST is not set}"
: "${POSTGRES_PORT:?POSTGRES_PORT is not set}"
: "${POSTGRES_USER:?POSTGRES_USER is not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is not set}"
: "${DAGSTER_DB:?DAGSTER_DB is not set}"

readonly APP_DIR="/opt/dagster/app"

# dagster.yaml обязан лежать в DAGSTER_HOME. Конфигурация версионируется
# в volume/dagster и копируется при каждом старте контейнера.
mkdir -p "${DAGSTER_HOME}"
install -m 0644 "${APP_DIR}/dagster.yaml" "${DAGSTER_HOME}/dagster.yaml"

# Metadata DB Dagster создаётся в существующем PostgreSQL, если её ещё нет:
# init-скрипты официального образа postgres на заполненном data/ не выполняются.
python - <<'PY'
import os
import time

import psycopg2
from psycopg2 import OperationalError, sql

connection_params = {
    "host": os.environ["POSTGRES_HOST"],
    "port": os.environ["POSTGRES_PORT"],
    "user": os.environ["POSTGRES_USER"],
    "password": os.environ["POSTGRES_PASSWORD"],
    "dbname": "postgres",
}

last_error: Exception | None = None
for _ in range(60):
    try:
        connection = psycopg2.connect(**connection_params, connect_timeout=5)
        break
    except OperationalError as error:
        last_error = error
        time.sleep(2)
else:
    raise SystemExit(f"PostgreSQL is not available: {last_error}")

connection.autocommit = True
with connection.cursor() as cursor:
    cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (os.environ["DAGSTER_DB"],))
    if cursor.fetchone() is None:
        cursor.execute(
            sql.SQL("CREATE DATABASE {}").format(sql.Identifier(os.environ["DAGSTER_DB"]))
        )
connection.close()
PY

exec dagster "$@"
