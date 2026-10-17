FROM apache/airflow:3.3.2-python3.12

USER root

# mc — штатный инструмент диагностики.
# gosu нужен entrypoint: контейнер стартует от root, чтобы поправить права на
# bind-mount логов, и сразу опускается до штатного uid 50000.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu mc \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint-dwh.sh
RUN chmod 0755 /entrypoint-dwh.sh

USER airflow

# Версии провайдеров зафиксированы официальными constraints Airflow 3.3.2.
RUN pip install --no-cache-dir \
        "apache-airflow-providers-postgres==7.0.2" \
        "apache-airflow-providers-clickhousedb==1.0.0" \
        --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-3.3.2/constraints-3.12.txt"
