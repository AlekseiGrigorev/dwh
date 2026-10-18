# DWH

Тестовая контейнерная инфраструктура для разработки и проверки DWH: PostgreSQL,
ClickHouse, Apache Airflow, Dagster, dbt Core и Elementary.
Запуск — локально через Docker Compose на Windows, Linux и macOS.

## Версии

| Компонент | Версия |
|---|---|
| PostgreSQL | `18.6-trixie` |
| ClickHouse | `26.9.13.15-jammy` |
| Apache Airflow | `3.3.2` (Python 3.12) |
| Airflow providers: postgres / clickhousedb | `7.0.2` / `1.0.0` |
| Dagster / dagster-webserver | `1.13.26` |
| dagster-postgres | `0.29.26` |
| Python (базовый образ Dagster) | `3.12.15` (slim-trixie) |
| psycopg2-binary | `2.9.13` |
| SQLAlchemy | `2.0.55` |
| dbt-core | `1.12.6` |
| dbt-postgres | `1.11.0` |
| dbt-clickhouse | `1.10.3` |
| Elementary CLI / dbt package | `0.26.1` |

dbt 2.x в этой инфраструктуре не используется: `dbt-clickhouse 1.10.3` и
`dbt-postgres 1.11.0` собраны под `dbt-core 1.x` (у `dbt-postgres` требование
`dbt-core<2.0`). Связка `dbt-core 1.12.6 + dbt-postgres 1.11.0 +
dbt-clickhouse 1.10.3 + elementary-data 0.26.1` проверена на совместимость.

Dagster собран из официального образа `python:3.12.15-slim-trixie`: отдельного
официального образа Dagster с тегом версии не публикуется, поэтому версия
зафиксирована в Dockerfile (`dagster 1.13.26` + `dagster-webserver 1.13.26`).
`dagster-postgres 0.29.26` — парная версия библиотеки: у неё собственная
0.x-нумерация и жёсткая зависимость `dagster==1.13.26`. Python 3.12 поддерживается
dagster (требование `>=3.10,<3.15`). SQLAlchemy зафиксирован на ветке 2.0: в 2.1
диалект `postgresql://` по умолчанию переключился на `psycopg` (v3), а
`dagster-postgres 0.29.26` работает через `psycopg2`.

## Требования

- Docker Engine 29+ (на Windows и macOS — Docker Desktop).
- Docker Compose v2.20+ (команда `docker compose`, не `docker-compose`).
- Не менее 10 ГБ памяти для Docker Desktop: Airflow и Dagster запускают несколько компонентов.
- Свободные порты `15432`, `18123`, `19000`, `18080`, `18081`, `13000`.
- Оболочка:
  - Windows — PowerShell 7 (`pwsh`);
  - Linux, macOS — POSIX-shell: `bash` или `zsh`.

Проект разворачивается и работает на Windows, Linux и macOS. Команды, одинаковые на всех
ОС, приведены один раз; команды, зависящие от оболочки, даны в двух вариантах —
PowerShell (Windows) и `bash`/`zsh` (Linux, macOS).

## Подготовка

1. Создайте `.env` из шаблона.

   Windows (PowerShell 7):

   ```powershell
   Copy-Item .env.example .env
   ```

   Linux, macOS (bash, zsh):

   ```bash
   cp .env.example .env
   ```

2. Заполните значения в `.env`. Обязательны:

   - `POSTGRES_PASSWORD`, `POSTGRES_USER`, `POSTGRES_DB`;
   - `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_USER`, `CLICKHOUSE_DB`;
   - `AIRFLOW_DB` (по умолчанию `airflow`), `AIRFLOW_ADMIN_USER`,
     `AIRFLOW_ADMIN_PASSWORD`, `AIRFLOW_JWT_SECRET`;
   - `DAGSTER_DB` (по умолчанию `dagster`);
   - `DBT_POSTGRES_SCHEMA`, `DBT_CLICKHOUSE_SCHEMA`.

   `.env` не коммитится, в `.env.example` только заглушки.

3. Учтите особенности значений:

   - `POSTGRES_HOST`, `POSTGRES_PORT`, `CLICKHOUSE_*` в `.env` — параметры для
     подключения **с хоста**. Внутри Docker-сети compose уже подставляет имена
     сервисов (`postgres_18.6-trixie`, `clickhouse_26.9.13.15-jammy`) и
     внутренние порты (`5432`, `8123`).
   - Пароль `POSTGRES_PASSWORD` и `CLICKHOUSE_PASSWORD` попадают в URI
     (`AIRFLOW__DATABASE__SQL_ALCHEMY_CONN`, `AIRFLOW_CONN_*`). Используйте
     URL-безопасные пароли (буквы, цифры, `_`, `-`); заглушка `change_me`
     подходит.
   - `AIRFLOW_ADMIN_PASSWORD` — пароль входа в UI Airflow, хранится только
     в `.env` и в файле SimpleAuthManager внутри контейнера.
   - Metadata DB `AIRFLOW_DB` создаётся автоматически; пользователь
     `POSTGRES_USER` должен иметь право `CREATEDB` (у `postgres` оно есть).
   - Metadata DB `DAGSTER_DB` создаётся автоматически тем же пользователем
     `POSTGRES_USER` (тоже требуется право `CREATEDB`); Dagster подключается
     к ней под `POSTGRES_USER`/`POSTGRES_PASSWORD`.

> Без заполненного `.env` compose завершится с ошибкой вида
> `POSTGRES_PASSWORD is not set` — это ожидаемое поведение.

## Платформы и особенности ОС

Compose-файлы используют относительные пути и переменные из `.env`, поэтому одинаково
работают на Windows, Linux и macOS. Отличия, которые нужно учитывать:

- **Оболочка.** На Windows команды выполняются в PowerShell 7, на Linux и macOS —
  в `bash`/`zsh`. Различаются только команды работы с файлами и окружением
  (копирование `.env`, активация виртуального окружения); команды `docker compose`
  идентичны.
- **Рабочая директория.** Все команды запускайте из корня репозитория: пути в compose
  относительные (`./postgres_18.6-trixie/data` и т. п.).
- **Кавычки в путях.** Заключайте пути в двойные кавычки — это работает и в PowerShell,
  и в `bash`/`zsh`.
- **Каталоги `data/`.** Bind-mount создаётся контейнером при первом запуске.
  Не копируйте `data/` между ОС и не переносите каталоги между Windows, Linux и macOS:
  владелец и права файлов различаются, контейнер может не запуститься. В Git данные
  не попадают (`*/data/` в `.gitignore`).
- **Права на Linux.** Файлы в `*/data` принадлежат пользователю контейнера. Контейнер
  Airflow стартует от `root` только чтобы выполнить `chown` каталога логов, создать
  metadata DB и записать пароль SimpleAuthManager, после чего сразу опускается до
  штатного uid `50000` через `gosu`. dbt-контейнер работает от `root` (так устроен
  официальный образ dbt), dagster-контейнер — тоже от `root` (базовый образ `python`).
- **Docker Desktop (Windows, macOS).** Bind-mount идёт через файловую систему ВМ:
  обмен с `data/` медленнее, чем на Linux.
- **Переводы строк.** Shell-скрипты, которые монтируются в Linux-контейнеры, сохраняйте
  с LF: CRLF внутри контейнера даёт ошибку `bad interpreter: no such file or directory`.
  Для `*.sh` это зафиксировано в `.gitattributes`.

## Запуск

Все команды `docker compose` ниже одинаковы для PowerShell и `bash`/`zsh`. Выполняйте их
из корня репозитория.

### Все контейнеры

```console
docker compose up -d --build
```

Если версия Compose ниже 2.20 и `include` не поддерживается:

```console
docker compose -f "docker-compose.postgres_18.6-trixie.yml" -f "docker-compose.clickhouse_26.9.13.15-jammy.yml" -f "docker-compose.airflow_3.3.2-python3.12.yml" -f "docker-compose.dagster_1.13.26.yml" -f "docker-compose.dbt-core_1.12.6.yml" up -d --build
```

### Отдельный контейнер

```console
docker compose -f "docker-compose.postgres_18.6-trixie.yml" up -d --build
docker compose -f "docker-compose.clickhouse_26.9.13.15-jammy.yml" up -d --build
docker compose -f "docker-compose.airflow_3.3.2-python3.12.yml" up -d --build
docker compose -f "docker-compose.dagster_1.13.26.yml" up -d --build
docker compose -f "docker-compose.dbt-core_1.12.6.yml" up -d --build
```

Airflow, Dagster и dbt обращаются к БД по именам сервисов. Запускайте их после PostgreSQL и
ClickHouse. При запуске отдельных файлов из корня репозитория compose использует одно
имя проекта (`dwh`) и общую сеть `dwh_default`, поэтому имена сервисов резолвятся.

### Airflow

Airflow запускается командой `airflow standalone`: api-server, scheduler, dag-processor
и triggerer работают в одном контейнере (режим для разработки). UI:
`http://localhost:18080`, логин и пароль — `AIRFLOW_ADMIN_USER` / `AIRFLOW_ADMIN_PASSWORD`.

Metadata DB `AIRFLOW_DB` создаётся entrypoint'ом в PostgreSQL, если её ещё нет.
Логи Airflow пишутся в `airflow_3.3.2-python3.12/data/logs`.

DAG `dwh_healthcheck` выполняет `SELECT 1` в PostgreSQL и ClickHouse через connections
`postgres_dwh` и `clickhouse_dwh` (создаются из `AIRFLOW_CONN_*`).

### Dagster

Dagster запускается командой `dagster dev`: webserver и daemon работают в одном
контейнере (режим для разработки). UI: `http://localhost:13000`, аутентификации
в OSS-версии нет. Metadata DB `DAGSTER_DB` создаётся entrypoint'ом в PostgreSQL,
состояние экземпляра (`DAGSTER_HOME`) пишется в `dagster_1.13.26/data`.

Код-локация — `volume/dagster/definitions.py`; ассеты `postgres_healthcheck` и
`clickhouse_healthcheck` выполняют `SELECT 1` в PostgreSQL и ClickHouse.

## Остановка

```console
docker compose down
```

`docker compose down -v` и удаление `*/data` не используйте: это удаляет данные,
логи и сгенерированные отчёты.

## Подключение

Значения пользователей, паролей и БД берутся из `.env`.

| Сервис | Хост | Порт | Пользователь / вход | База |
|---|---|---|---|---|
| PostgreSQL | localhost | 15432 | `POSTGRES_USER` | `POSTGRES_DB` |
| ClickHouse (HTTP) | localhost | 18123 | `CLICKHOUSE_USER` | `CLICKHOUSE_DB` |
| ClickHouse (native) | localhost | 19000 | `CLICKHOUSE_USER` | `CLICKHOUSE_DB` |
| Airflow UI | localhost | 18080 | `AIRFLOW_ADMIN_USER` | — |
| Dagster UI | localhost | 13000 | — (без аутентификации) | — |
| dbt docs (опционально) | localhost | 18081 | — | — |

Примеры (одинаково для PowerShell и `bash`/`zsh`):

```console
docker compose exec postgres_18.6-trixie psql -U postgres -d test
docker compose exec clickhouse_26.9.13.15-jammy clickhouse-client --query "SELECT version()"
```

## Airflow

Проверка DAG-ов и провайдеров (команды одинаковы на всех ОС):

```console
docker compose exec airflow_3.3.2-python3.12 airflow dags list
docker compose exec airflow_3.3.2-python3.12 airflow dags test dwh_healthcheck
docker compose exec airflow_3.3.2-python3.12 airflow providers list
```

`airflow dags test dwh_healthcheck` прогоняет оба таска: подключение к PostgreSQL и
ClickHouse. Результат виден в UI (`http://localhost:18080`) и в логах контейнера.
DAG создаётся на паузе (`AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=true`): включите его
в UI или командой `docker compose exec airflow_3.3.2-python3.12 airflow dags unpause dwh_healthcheck`.

## Dagster

Код-локация лежит в `volume/dagster` и монтируется в контейнер как `/opt/dagster/app`
(только чтение). `dagster.yaml` из этого каталога entrypoint копирует в `DAGSTER_HOME`
при старте; секретов в нём нет — параметры берутся из окружения контейнера.
Состояние экземпляра (runs, event log, расписания) хранится в PostgreSQL (`DAGSTER_DB`),
а `DAGSTER_HOME` — в `dagster_1.13.26/data`.

`dagster dev` — development-режим (`DAGSTER_IS_DEV_CLI=1`): schedules и sensors
создаются остановленными, запуски из UI выполняются внутри контейнера.

Команды выполняются внутри контейнера (одинаковы на всех ОС):

```console
docker compose exec dagster_1.13.26 dagster --version
docker compose exec dagster_1.13.26 dagster definitions validate -f /opt/dagster/app/definitions.py
docker compose exec dagster_1.13.26 dagster asset list -f /opt/dagster/app/definitions.py
docker compose exec dagster_1.13.26 dagster asset materialize --select "*" -f /opt/dagster/app/definitions.py
```

`dagster asset materialize` материализует оба ассета: `postgres_healthcheck` и
`clickhouse_healthcheck`. Команда помечена в Dagster как устаревшая в пользу
`dg launch` (CLI `dg` ставится отдельным пакетом и в образ не входит), поэтому
выводит предупреждение, но работает. Результат виден в UI (`http://localhost:13000`).

Первый старт контейнера применяет миграции Dagster в `DAGSTER_DB` и может занять
до минуты; healthcheck — запрос `GET /server_info`.

При старте в логах есть предупреждение `SupersessionWarning` с советом использовать
`dg dev`: CLI `dg` ставится отдельным пакетом и в образ не входит, `dagster dev`
в версии 1.13.26 работает штатно. Предупреждение информационное.

## dbt

dbt-проект лежит в `volume/dbt` и монтируется в контейнер как `/dbt/project`.
Профиль `profiles.yml` подключается только через переменные окружения из `.env`,
секретов в нём нет. Доступны два target: `postgres` и `clickhouse`. Профиль `dwh`
используется самим dbt, профиль `elementary` — внутренним dbt-проектом Elementary CLI.

Команды выполняются внутри контейнера (одинаковы на всех ОС):

```console
# принудительное обновление пакетов (при старте выполняется автоматически)
docker compose exec dbt-core_1.12.6 dbt deps
docker compose exec dbt-core_1.12.6 dbt debug --target postgres
docker compose exec dbt-core_1.12.6 dbt debug --target clickhouse
docker compose exec dbt-core_1.12.6 dbt run --target postgres
docker compose exec dbt-core_1.12.6 dbt test --target postgres
docker compose exec dbt-core_1.12.6 dbt run --select elementary --target postgres
```

Для ClickHouse замените `--target postgres` на `--target clickhouse`.

`dbt deps` скачивает пакет `elementary-data/elementary 0.26.1` и его зависимости в
`dbt-core_1.12.6/data/dbt_packages`; файл `volume/dbt/package-lock.yml` фиксирует
версии пакетов и коммитится в репозиторий.

При старте контейнера entrypoint сам выполняет `dbt deps`, если пакеты отсутствуют
или изменились `packages.yml`/`package-lock.yml` (маркер —
`dbt-core_1.12.6/data/.dbt-deps.sha256`). Поэтому на чистом клоне достаточно
`docker compose up -d --build`; первый старт dbt-контейнера может занять
дополнительное время и требует доступа к dbt Hub. Ошибка `dbt deps` не блокирует
запуск контейнера: предупреждение попадёт в `docker compose logs -f dbt-core_1.12.6`,
а пакеты можно поставить вручную командой
`docker compose exec dbt-core_1.12.6 dbt deps`.

## Отчёты

Nginx не используется: отчёты — самодостаточные HTML-файлы, они сохраняются на хосте
через bind-mount и открываются в браузере.

### dbt docs

```console
docker compose exec dbt-core_1.12.6 dbt docs generate --static --target postgres
```

Флаг `--static` обязателен: он создаёт `target/static_index.html` — один файл с
вшитыми `manifest.json` и `catalog.json`, который открывается напрямую. Обычный
`target/index.html` подгружает JSON отдельно и без HTTP-сервера может не открыться.

Открыть на хосте:

```text
dbt-core_1.12.6/data/target/static_index.html
```

### Elementary

Перед генерацией отчёта модели Elementary должны быть созданы в БД:

```console
docker compose exec dbt-core_1.12.6 dbt run --select elementary --target postgres
docker compose exec dbt-core_1.12.6 dbt test --target postgres
docker compose exec dbt-core_1.12.6 edr report --project-dir /dbt/project --profiles-dir /dbt/project --profile-target postgres --target-path /dbt/artifacts/edr_target --file-path /dbt/artifacts/elementary/index.html --open-browser=False
```

Открыть на хосте:

```text
dbt-core_1.12.6/data/elementary/index.html
```

Для ClickHouse используйте `--profile-target clickhouse` и предварительно
`dbt run --select elementary --target clickhouse`.

### dbt docs serve (опционально)

Если нужен HTTP-доступ вместо открытия файла:

```console
docker compose exec dbt-core_1.12.6 dbt docs serve --host 0.0.0.0 --port 8080 --no-browser
```

Отчёт будет доступен по адресу `http://localhost:18081` (порт `8080` контейнера
опубликован как `18081`).

## Проверка состояния

```console
docker compose ps
docker compose logs -f airflow_3.3.2-python3.12
docker compose logs -f dagster_1.13.26
docker compose logs -f dbt-core_1.12.6
```

У PostgreSQL, ClickHouse, Airflow и Dagster есть `healthcheck`; в `docker compose ps`
статус должен быть `healthy`. У Dagster проверяется `GET /server_info`, первый старт
дольше обычного: применяются миграции в `DAGSTER_DB`. У dbt-контейнера healthcheck нет:
это среда выполнения команд, он постоянно запущен и проверяется через `docker compose exec`.

## Структура репозитория

```text
.
├── airflow_3.3.2-python3.12/              # Dockerfile, entrypoint, data/logs
├── clickhouse_26.9.13.15-jammy/           # Dockerfile контейнера ClickHouse
├── dagster_1.13.26/                       # Dockerfile, entrypoint, data/ (DAGSTER_HOME)
├── dbt-core_1.12.6/                       # Dockerfile, data/ (target, elementary, ...)
├── postgres_18.6-trixie/                  # Dockerfile контейнера PostgreSQL
├── volume/
│   ├── airflow/dags/                      # DAG-и Airflow
│   ├── dagster/                           # код-локация и dagster.yaml
│   └── dbt/                               # dbt-проект (профиль, модели, пакеты)
├── docker-compose.airflow_3.3.2-python3.12.yml
├── docker-compose.clickhouse_26.9.13.15-jammy.yml
├── docker-compose.dagster_1.13.26.yml
├── docker-compose.dbt-core_1.12.6.yml
├── docker-compose.postgres_18.6-trixie.yml
├── docker-compose.yml                     # все контейнеры через include
├── .env.example
└── .clinerules/main.md                    # правила проекта
```

Данные, логи и отчёты контейнеров хранятся в `<директория>/data` и не коммитятся.
Каталоги создаёт Docker при первом запуске на текущей ОС; не переносите их между
Windows, Linux и macOS (см. раздел «Платформы и особенности ОС»).

## Диагностика

Команды одинаковы для PowerShell и `bash`/`zsh`.

```console
# Проверить конфигурацию без запуска
docker compose config

# Проверить отдельные файлы
docker compose -f "docker-compose.airflow_3.3.2-python3.12.yml" config -q
docker compose -f "docker-compose.dagster_1.13.26.yml" config -q
docker compose -f "docker-compose.dbt-core_1.12.6.yml" config -q

# Пересобрать один сервис
docker compose up -d --build airflow_3.3.2-python3.12

# Открыть Midnight Commander внутри контейнера (mc установлен во всех образах)
docker compose exec postgres_18.6-trixie mc
docker compose exec clickhouse_26.9.13.15-jammy mc
docker compose exec airflow_3.3.2-python3.12 mc
docker compose exec dagster_1.13.26 mc
docker compose exec dbt-core_1.12.6 mc
```

## Примечания

- `airflow standalone` — официальный development-режим Airflow. Для тестовой
  инфраструктуры этого достаточно; при необходимости Airflow можно разложить на
  отдельные сервисы api-server/scheduler/dag-processor/triggerer.
- `dagster dev` — development-режим Dagster: webserver и daemon в одном контейнере,
  без аутентификации. Для production-подобного развёртывания Dagster разделяют на
  webserver, daemon и code server, но для тестовой инфраструктуры достаточно dev-режима.
- Первый `docker compose up -d --build` скачивает образы и ставит пакеты — это
  занимает время и требует доступа в интернет. `dbt deps` также требует сети и
  может выполняться автоматически при первом старте dbt-контейнера.
- `dbt docs generate --static` создаёт `static_index.html`; без `--static` отчёт
  зависит от `manifest.json`/`catalog.json` и обычно требует HTTP-сервера.
- Nginx в инфраструктуру не входит: HTML-отчёты открываются напрямую, а
  `dbt docs serve` — встроенный сервер dbt, который запускается по требованию.
