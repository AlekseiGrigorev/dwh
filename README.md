# DWH

Тестовая контейнерная инфраструктура для разработки и проверки DWH: PostgreSQL и ClickHouse.
Запуск — локально через Docker Compose на Windows, Linux и macOS.

## Требования

- Docker Engine 29+ (на Windows и macOS — Docker Desktop).
- Docker Compose v2.20+ (команда `docker compose`, не `docker-compose`).
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

2. Заполните значения в `.env` (минимум `POSTGRES_PASSWORD` и `CLICKHOUSE_PASSWORD`).
   `.env` не коммитится, в `.env.example` только заглушки.

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
- **Права на Linux.** Файлы в `*/data` принадлежат пользователю контейнера. Не меняйте
  владельца каталога вручную и не запускайте Docker через `sudo` без необходимости.
- **Docker Desktop (Windows, macOS).** Bind-mount идёт через файловую систему ВМ:
  обмен с `data/` медленнее, чем на Linux.
- **Переводы строк.** Shell-скрипты, которые монтируются в Linux-контейнеры, сохраняйте
  с LF: CRLF внутри контейнера даёт ошибку `bad interpreter: no such file or directory`.

## Запуск

Все команды `docker compose` ниже одинаковы для PowerShell и `bash`/`zsh`. Выполняйте их
из корня репозитория.

### Все контейнеры

```console
docker compose up -d --build
```

Если версия Compose ниже 2.20 и `include` не поддерживается:

```console
docker compose -f "docker-compose.postgres_18.6-trixie.yml" -f "docker-compose.clickhouse_26.9.13.15-jammy.yml" up -d --build
```

### Отдельный контейнер

```console
docker compose -f "docker-compose.postgres_18.6-trixie.yml" up -d --build
docker compose -f "docker-compose.clickhouse_26.9.13.15-jammy.yml" up -d --build
```

## Остановка

```console
docker compose down
```

`docker compose down -v` и удаление `*/data` не используйте: это удаляет данные.

## Подключение

Значения пользователей, паролей и БД берутся из `.env`.

| Сервис     | Хост      | Порт  | Пользователь         | База              |
|------------|-----------|-------|----------------------|-------------------|
| PostgreSQL | localhost | 15432 | `POSTGRES_USER`      | `POSTGRES_DB`     |
| ClickHouse | localhost | 18123 | `CLICKHOUSE_USER`    | `CLICKHOUSE_DB`   |
| ClickHouse | localhost | 19000 | `CLICKHOUSE_USER`    | `CLICKHOUSE_DB`   |

Примеры (одинаково для PowerShell и `bash`/`zsh`):

```console
docker compose exec postgres_18.6-trixie psql -U postgres -d test
docker compose exec clickhouse_26.9.13.15-jammy clickhouse-client --query "SELECT version()"
```

## Проверка состояния

```console
docker compose ps
docker compose logs -f postgres_18.6-trixie
docker compose logs -f clickhouse_26.9.13.15-jammy
```

Оба сервиса имеют `healthcheck`; в `docker compose ps` статус должен быть `healthy`.

## dbt

dbt-проект в репозиторий пока не добавлен. Когда появится, зависимости ставятся
в виртуальное окружение `.venv` (оно в `.gitignore`).

Windows (PowerShell 7):

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Linux, macOS (bash, zsh):

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Проверка подключения — из директории dbt-проекта (команда одинакова на всех ОС):

```console
dbt debug
```

## Отчёты

Отчёты dbt (после добавления dbt-проекта, команды одинаковы на всех ОС):

```console
dbt docs generate
dbt docs serve --port 8080
```

Отчёты публикуются на хосте как `http://localhost:18081` (см. `.clinerules/main.md`, п. 5).

## Структура репозитория

```text
.
├── clickhouse_26.9.13.15-jammy/           # Dockerfile контейнера ClickHouse
├── postgres_18.6-trixie/                  # Dockerfile контейнера PostgreSQL
├── volume/                                # общие монтируемые ресурсы
├── docker-compose.clickhouse_26.9.13.15-jammy.yml
├── docker-compose.postgres_18.6-trixie.yml
├── docker-compose.yml                     # все контейнеры через include
├── .env.example
└── .clinerules/main.md                    # правила проекта
```

Данные контейнеров хранятся в `<директория>/data` и не коммитятся. Каталоги создаёт
Docker при первом запуске на текущей ОС; не переносите их между Windows, Linux и macOS
(см. раздел «Платформы и особенности ОС»).

## Диагностика

Команды одинаковы для PowerShell и `bash`/`zsh`.

```console
# Проверить конфигурацию без запуска
docker compose config

# Проверить отдельный файл
docker compose -f "docker-compose.postgres_18.6-trixie.yml" config -q

# Пересобрать один сервис
docker compose up -d --build postgres_18.6-trixie

# Открыть Midnight Commander внутри контейнера (mc установлен во всех образах)
docker compose exec postgres_18.6-trixie mc
docker compose exec clickhouse_26.9.13.15-jammy mc
```
