"""Smoke-test DAG: проверяет доступность PostgreSQL и ClickHouse."""

from __future__ import annotations

from datetime import datetime

from airflow.providers.clickhousedb.hooks.clickhouse import ClickHouseHook
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import DAG, task

with DAG(
    dag_id="dwh_healthcheck",
    description="Проверка подключений DWH к PostgreSQL и ClickHouse",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dwh", "healthcheck"],
) as dag:

    @task
    def check_postgres() -> None:
        value = PostgresHook(postgres_conn_id="postgres_dwh").get_first("SELECT 1")[0]
        if value != 1:
            raise ValueError(f"PostgreSQL вернул {value!r} вместо 1")

    @task
    def check_clickhouse() -> None:
        value = ClickHouseHook(clickhouse_conn_id="clickhouse_dwh").get_first("SELECT 1")[0]
        if value != 1:
            raise ValueError(f"ClickHouse вернул {value!r} вместо 1")

    check_postgres() >> check_clickhouse()
