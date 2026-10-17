#!/usr/bin/env bash
# Bootstrap dbt-пакетов перед запуском долгоживущего контейнера.
# dbt deps выполняется только если пакеты отсутствуют или изменились
# packages.yml / package-lock.yml / версия dbt-core.
set -euo pipefail

readonly PROJECT_DIR="/dbt/project"
readonly ARTIFACTS_DIR="/dbt/artifacts"
readonly PACKAGES_DIR="${DBT_PACKAGES_INSTALL_PATH:-${PROJECT_DIR}/dbt_packages}"
readonly PACKAGES_FILE="${PROJECT_DIR}/packages.yml"
readonly LOCK_FILE="${PROJECT_DIR}/package-lock.yml"
readonly MARKER_FILE="${ARTIFACTS_DIR}/.dbt-deps.sha256"

cd "${PROJECT_DIR}"

compute_hash() {
    {
        cat "${PACKAGES_FILE}"
        if [[ -f "${LOCK_FILE}" ]]; then
            cat "${LOCK_FILE}"
        fi
        python -c 'import importlib.metadata; print(importlib.metadata.version("dbt-core"))'
    } | sha256sum | awk '{print $1}'
}

packages_installed() {
    [[ -d "${PACKAGES_DIR}/elementary" ]]
}

current_hash=""
if ! current_hash="$(compute_hash)"; then
    echo "[dbt] WARNING: cannot compute packages hash" >&2
fi

if packages_installed \
    && [[ -f "${MARKER_FILE}" ]] \
    && [[ "$(cat "${MARKER_FILE}")" == "${current_hash}" ]]; then
    echo "[dbt] Packages are up to date, skipping dbt deps"
else
    echo "[dbt] Installing packages (dbt deps)"
    installed=false
    for attempt in 1 2 3; do
        if dbt deps; then
            installed=true
            break
        fi
        echo "[dbt] dbt deps attempt ${attempt} failed" >&2
        sleep 5
    done

    if [[ "${installed}" == "true" ]] && packages_installed; then
        if compute_hash > "${MARKER_FILE}"; then
            echo "[dbt] Packages installed"
        else
            echo "[dbt] WARNING: packages installed, but marker was not written" >&2
        fi
    else
        echo "[dbt] WARNING: dbt deps failed; starting without updated packages" >&2
        echo "[dbt] Run 'docker compose exec dbt-core_1.12.6 dbt deps' manually" >&2
    fi
fi

exec sleep infinity
