FROM python:3.12.15-slim-trixie

# Базовый образ python запускается от root, поэтому после установки пакетов
# пользователя менять не нужно (аналогично dbt-core_1.12.6).
USER root

# mc — штатный инструмент диагностики; curl — для healthcheck webserver.
RUN apt-get update \
    && apt-get install -y --no-install-recommends mc curl \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint-dagster.sh
RUN chmod 0755 /entrypoint-dagster.sh

# dagster-postgres 0.29.26 собран под dagster 1.13.26 (жёсткая зависимость ==).
# dagster-webserver нужен команде `dagster dev`: она поднимает webserver и daemon.
# SQLAlchemy зафиксирован на ветке 2.0: в 2.1 диалект postgresql:// по умолчанию
# переключился на psycopg (v3), а dagster-postgres 0.29.26 работает через psycopg2.
RUN pip install --no-cache-dir \
        "dagster==1.13.26" \
        "dagster-webserver==1.13.26" \
        "dagster-postgres==0.29.26" \
        "psycopg2-binary==2.9.13" \
        "SQLAlchemy==2.0.55"

# DAGSTER_HOME — постоянный каталог экземпляра (bind-mount ./dagster_1.13.26/data).
ENV DAGSTER_HOME=/opt/dagster/dagster_home
WORKDIR ${DAGSTER_HOME}
