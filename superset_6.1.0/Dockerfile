FROM apache/superset:6.1.0

USER root

# mc — штатный инструмент диагностики.
# gosu нужен entrypoint: контейнер стартует от root, чтобы поправить права на
# bind-mount SUPERSET_HOME, и сразу опускается до штатного пользователя superset.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu mc \
    && rm -rf /var/lib/apt/lists/*

# psycopg2 — metadata DB Superset в PostgreSQL: в lean-образе драйвера нет.
# clickhouse-connect — единственный драйвер ClickHouse, поддерживаемый
# Superset 6.1.0 (extra clickhouse: clickhouse-connect>=0.13.0,<1.0).
# clickhouse-sqlalchemy здесь не используется: его ветка 0.3.x требует
# SQLAlchemy 2.0, а Superset 6.1.0 зафиксирован на SQLAlchemy 1.4.54.
# Образ держит пакеты в venv /app/.venv, pip в нём нет — установка через uv.
RUN uv pip install --no-cache --python /app/.venv/bin/python \
        "psycopg2-binary==2.9.13" \
        "clickhouse-connect[sqlalchemy]==0.15.1"

COPY entrypoint.sh /entrypoint-superset.sh
RUN chmod 0755 /entrypoint-superset.sh

USER superset
