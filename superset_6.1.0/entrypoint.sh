#!/usr/bin/env bash
# Подготовка Superset перед запуском gunicorn (run-server.sh):
# metadata DB в PostgreSQL, миграции, роли/permissions и администратор.
set -euo pipefail

: "${SUPERSET_SECRET_KEY:?SUPERSET_SECRET_KEY is not set}"
: "${SUPERSET__SQLALCHEMY_DATABASE_URI:?SUPERSET__SQLALCHEMY_DATABASE_URI is not set}"
: "${SUPERSET_HOME:?SUPERSET_HOME is not set}"
: "${POSTGRES_HOST:?POSTGRES_HOST is not set}"
: "${POSTGRES_PORT:?POSTGRES_PORT is not set}"
: "${POSTGRES_USER:?POSTGRES_USER is not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is not set}"
: "${SUPERSET_DB:?SUPERSET_DB is not set}"
: "${SUPERSET_ADMIN_USER:?SUPERSET_ADMIN_USER is not set}"
: "${SUPERSET_ADMIN_PASSWORD:?SUPERSET_ADMIN_PASSWORD is not set}"
: "${SUPERSET_ADMIN_EMAIL:?SUPERSET_ADMIN_EMAIL is not set}"

# Bind-mount SUPERSET_HOME создаётся Docker от root — возвращаем владельца
# штатному пользователю образа и сразу опускаем привилегии: root нужен только
# для chown (тот же приём, что в airflow_3.3.2-python3.12/entrypoint.sh).
if [[ "$(id -u)" == "0" ]]; then
    mkdir -p "${SUPERSET_HOME}"
    chown -R superset:superset "${SUPERSET_HOME}"
    exec gosu superset /entrypoint-superset.sh "$@"
fi

# Metadata DB Superset создаётся в существующем PostgreSQL, если её ещё нет:
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

last_error = None
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
    cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (os.environ["SUPERSET_DB"],))
    if cursor.fetchone() is None:
        cursor.execute(
            sql.SQL("CREATE DATABASE {}").format(sql.Identifier(os.environ["SUPERSET_DB"]))
        )
connection.close()
PY

# Миграции и default-роли/permissions идемпотентны: их можно запускать на каждом старте.
# Порядок отличается от официального docker-init.sh (там create-admin до init):
# роль Admin гарантированно существует после `superset init`.
echo "[superset] Applying metadata DB migrations"
superset db upgrade

echo "[superset] Creating default roles and permissions"
superset init

# Администратор создаётся только если его ещё нет: повторный старт не падает.
# Пароль существующего пользователя не перезаписывается — для смены используйте UI.
echo "[superset] Ensuring admin user"
python - <<'PY'
import os

from superset.app import create_app

app = create_app()
with app.app_context():
    from superset.extensions import appbuilder

    security_manager = appbuilder.sm
    username = os.environ["SUPERSET_ADMIN_USER"]

    if security_manager.find_user(username=username) is not None:
        print(f"[superset] user {username} already exists, password is not changed")
    else:
        user = security_manager.add_user(
            username=username,
            first_name="Superset",
            last_name="Admin",
            email=os.environ["SUPERSET_ADMIN_EMAIL"],
            role=security_manager.find_role("Admin"),
            password=os.environ["SUPERSET_ADMIN_PASSWORD"],
        )
        if not user:
            raise SystemExit(f"[superset] cannot create user {username}")
        print(f"[superset] user {username} created")
PY

if [[ "$#" -eq 0 ]]; then
    set -- /usr/bin/run-server.sh
fi

echo "[superset] Starting web server: $*"
exec "$@"
