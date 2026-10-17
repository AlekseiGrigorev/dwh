FROM ghcr.io/dbt-labs/dbt-core:1.12.6

USER root

# mc — штатный инструмент диагностики. Базовый образ работает от root,
# поэтому после установки пакетов пользователя менять не нужно.
RUN apt-get update \
    && apt-get install -y --no-install-recommends mc \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint-dbt.sh
RUN chmod 0755 /entrypoint-dbt.sh

# dbt-core зафиксирован тегом базового образа; адаптеры и Elementary — явно.
# dbt 2.x не используется: dbt-clickhouse 1.10.3 и dbt-postgres 1.11.0 собраны
# под dbt-core 1.x (у dbt-postgres требование dbt-core<2.0).
RUN pip install --no-cache-dir \
        "dbt-core==1.12.6" \
        "dbt-postgres==1.11.0" \
        "dbt-clickhouse==1.10.3" \
        "elementary-data==0.26.1"

WORKDIR /dbt/project
