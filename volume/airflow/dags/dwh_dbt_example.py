"""Пример DAG-а: dbt-модели из volume/dbt запускаются задачами Airflow (Cosmos).

Cosmos парсит тот же dbt-проект, что монтируется в dbt-core_1.12.6, и создаёт
задачу на каждую модель. dbt запускается из venv образа
(/home/airflow/dbt-venv/bin/dbt), артефакты пишутся в
airflow_3.3.2-python3.12/data/dbt-artifacts.
"""

from __future__ import annotations

import os
from datetime import datetime

from cosmos import (
    DbtDag,
    ExecutionConfig,
    InvocationMode,
    ProfileConfig,
    ProjectConfig,
    RenderConfig,
)

# Пути заданы в docker-compose.airflow_3.3.2-python3.12.yml.
DBT_PROJECT_DIR = os.environ["DBT_PROJECT_DIR"]
DBT_EXECUTABLE_PATH = os.environ["DBT_EXECUTABLE_PATH"]

# dbt_project_path задаётся только в ProjectConfig: Cosmos сам передаёт его в
# RenderConfig и ExecutionConfig, а одновременное указание — ошибка конфигурации.
dwh_dbt_example = DbtDag(
    dag_id="dwh_dbt_example",
    description="dbt-модели DWH как задачи Airflow (Cosmos)",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["dwh", "dbt"],
    project_config=ProjectConfig(
        dbt_project_path=DBT_PROJECT_DIR,
        # Пакеты dbt ставит entrypoint контейнера при старте, поэтому `dbt deps`
        # не выполняется при каждом парсинге DAG.
        install_dbt_deps=False,
    ),
    profile_config=ProfileConfig(
        profile_name="dwh",
        # Для ClickHouse замените target на "clickhouse".
        target_name="postgres",
        profiles_yml_filepath=f"{DBT_PROJECT_DIR}/profiles.yml",
    ),
    execution_config=ExecutionConfig(
        dbt_executable_path=DBT_EXECUTABLE_PATH,
        # dbt установлен в venv образа, а не в окружение Airflow, поэтому dbt
        # вызывается как внешний процесс (InvocationMode.DBT_RUNNER требует dbt
        # в том же окружении и запрещает свой путь к бинарю).
        invocation_mode=InvocationMode.SUBPROCESS,
    ),
    render_config=RenderConfig(
        dbt_executable_path=DBT_EXECUTABLE_PATH,
        invocation_mode=InvocationMode.SUBPROCESS,
        # Демонстрационный DAG: только пример-модель из volume/dbt/models/example.
        select=["path:models/example"],
    ),
)
