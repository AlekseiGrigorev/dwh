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

# dbt в отдельном venv: Cosmos вызывает dbt как внешний процесс, поэтому версии
# dbt не конфликтуют с зависимостями Airflow. Версии те же, что в образе
# dbt-core_1.12.6 (dbt 2.x не используется: dbt-postgres 1.11.0 требует dbt-core<2.0).
RUN python -m venv /home/airflow/dbt-venv \
    && /home/airflow/dbt-venv/bin/pip install --no-cache-dir \
        "dbt-core==1.12.6" \
        "dbt-postgres==1.11.0" \
        "dbt-clickhouse==1.10.3" \
        "elementary-data==0.26.1"

# Cosmos — мост dbt↔Airflow: парсит dbt-проект и запускает модели задачами Airflow.
# Constraints те же, что у провайдеров: без них pip может двинуть версии Airflow.
RUN pip install --no-cache-dir "astronomer-cosmos==1.15.1" \
        --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-3.3.2/constraints-3.12.txt"
