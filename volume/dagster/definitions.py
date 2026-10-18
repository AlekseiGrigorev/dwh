"""Smoke-test код-локация Dagster: проверка доступности PostgreSQL и ClickHouse."""

from __future__ import annotations

import base64
import os
from contextlib import closing
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import psycopg2
from dagster import Definitions, asset


def _require(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Переменная окружения {name} не задана")
    return value


@asset(group_name="healthcheck", description="Проверка подключения к PostgreSQL")
def postgres_healthcheck() -> None:
    with closing(
        psycopg2.connect(
            host=_require("POSTGRES_HOST"),
            port=int(_require("POSTGRES_PORT")),
            user=_require("POSTGRES_USER"),
            password=_require("POSTGRES_PASSWORD"),
            dbname=_require("POSTGRES_DB"),
            connect_timeout=10,
        )
    ) as connection, connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        value = cursor.fetchone()[0]

    if value != 1:
        raise ValueError(f"PostgreSQL вернул {value!r} вместо 1")


@asset(group_name="healthcheck", description="Проверка подключения к ClickHouse по HTTP")
def clickhouse_healthcheck() -> None:
    credentials = base64.b64encode(
        f"{_require('CLICKHOUSE_USER')}:{_require('CLICKHOUSE_PASSWORD')}".encode()
    ).decode()
    query = urlencode({"query": "SELECT 1"})
    url = f"http://{_require('CLICKHOUSE_HOST')}:{_require('CLICKHOUSE_HTTP_PORT')}/?{query}"
    request = Request(url, headers={"Authorization": f"Basic {credentials}"})

    with urlopen(request, timeout=10) as response:
        body = response.read().decode().strip()

    if body != "1":
        raise ValueError(f"ClickHouse вернул {body!r} вместо '1'")


defs = Definitions(assets=[postgres_healthcheck, clickhouse_healthcheck])
