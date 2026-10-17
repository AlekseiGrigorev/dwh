#!/usr/bin/env bash
# Подготовка окружения Airflow перед запуском `airflow standalone`.
# Запускается от root; рабочие процессы Airflow — от штатного uid 50000.
set -euo pipefail

readonly AIRFLOW_UID="${AIRFLOW_UID:-50000}"
readonly AIRFLOW_GID="${AIRFLOW_GID:-0}"
readonly AIRFLOW_USER_HOME="${AIRFLOW_USER_HOME_DIR:-/home/airflow}"

: "${POSTGRES_HOST:?POSTGRES_HOST is not set}"
: "${POSTGRES_PORT:?POSTGRES_PORT is not set}"
: "${POSTGRES_USER:?POSTGRES_USER is not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is not set}"
: "${AIRFLOW_DB:?AIRFLOW_DB is not set}"
: "${AIRFLOW_ADMIN_USER:?AIRFLOW_ADMIN_USER is not set}"
: "${AIRFLOW_ADMIN_PASSWORD:?AIRFLOW_ADMIN_PASSWORD is not set}"

# Bind-mount logs создаётся Docker от root — возвращаем владельца штатному пользователю.
mkdir -p "${AIRFLOW_HOME}/logs"
chown -R "${AIRFLOW_UID}:${AIRFLOW_GID}" "${AIRFLOW_HOME}/logs"

# Metadata DB Airflow создаётся в существующем PostgreSQL, если её ещё нет.
gosu "${AIRFLOW_UID}:${AIRFLOW_GID}" env HOME="${AIRFLOW_USER_HOME}" python - <<'PY'
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
        connection = psycopg2.connect(**connection_params)
        break
    except OperationalError as error:
        last_error = error
        time.sleep(2)
else:
    raise SystemExit(f"PostgreSQL is not available: {last_error}")

connection.autocommit = True
with connection.cursor() as cursor:
    cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (os.environ["AIRFLOW_DB"],))
    if cursor.fetchone() is None:
        cursor.execute(
            sql.SQL("CREATE DATABASE {}").format(sql.Identifier(os.environ["AIRFLOW_DB"]))
        )
connection.close()
PY

# SimpleAuthManager Airflow 3 хранит пароли в JSON-файле. Заполняем его из .env,
# чтобы логин в UI был детерминированным (иначе Airflow сгенерирует случайный пароль).
gosu "${AIRFLOW_UID}:${AIRFLOW_GID}" env HOME="${AIRFLOW_USER_HOME}" python - <<'PY'
import json
import os

passwords_file = os.path.join(
    os.environ["AIRFLOW_HOME"], "simple_auth_manager_passwords.json.generated"
)
with open(passwords_file, "w", encoding="utf-8") as file:
    json.dump(
        {os.environ["AIRFLOW_ADMIN_USER"]: os.environ["AIRFLOW_ADMIN_PASSWORD"]},
        file,
    )
PY

exec gosu "${AIRFLOW_UID}:${AIRFLOW_GID}" env HOME="${AIRFLOW_USER_HOME}" /entrypoint "$@"
