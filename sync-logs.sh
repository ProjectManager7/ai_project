#!/bin/bash
# Traefik Logs Auto-Sync Script for Fail2ban
# Синхронизирует логи Traefik из контейнера на хост для fail2ban

# Конфигурация
PROJECT_DIR="/root/ai_project"
LOG_DIR="${PROJECT_DIR}/logs"
TRAEFIK_CONTAINER="service_traefik"
LOG_FILE="access.log"

# Функция логирования
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_DIR}/sync.log"
}

# Проверка существования контейнера
if ! docker ps --format "{{.Names}}" | grep -q "^${TRAEFIK_CONTAINER}$"; then
    log_message "ERROR: Container ${TRAEFIK_CONTAINER} not found or not running"
    exit 1
fi

# Создание директории логов если не существует
mkdir -p "${LOG_DIR}"

# Синхронизация логов
cd "${PROJECT_DIR}" || exit 1

# Копирование логов из контейнера
if docker exec "${TRAEFIK_CONTAINER}" test -f "/var/log/${LOG_FILE}"; then
    # Копируем лог во временную папку контейнера
    if docker exec "${TRAEFIK_CONTAINER}" cp "/var/log/${LOG_FILE}" "/tmp/sync_${LOG_FILE}"; then
        # Копируем из контейнера на хост
        if docker cp "${TRAEFIK_CONTAINER}:/tmp/sync_${LOG_FILE}" "${LOG_DIR}/${LOG_FILE}"; then
            # Удаляем временный файл из контейнера
            docker exec "${TRAEFIK_CONTAINER}" rm -f "/tmp/sync_${LOG_FILE}" 2>/dev/null
            
            # Устанавливаем корректные права
            chmod 644 "${LOG_DIR}/${LOG_FILE}"
            
            # Перезагружаем fail2ban для чтения новых логов
            if systemctl is-active --quiet fail2ban; then
                sudo fail2ban-client reload traefik-general >/dev/null 2>&1
                sudo fail2ban-client reload nodered-auth >/dev/null 2>&1
                sudo fail2ban-client reload flowise-auth >/dev/null 2>&1
                log_message "SUCCESS: Logs synced and fail2ban reloaded"
            else
                log_message "WARNING: fail2ban service not active"
            fi
        else
            log_message "ERROR: Failed to copy logs from container to host"
            exit 1
        fi
    else
        log_message "ERROR: Failed to copy logs within container"
        exit 1
    fi
else
    log_message "WARNING: Log file /var/log/${LOG_FILE} not found in container"
    exit 1
fi

# Очистка старых логов синхронизации (оставляем последние 1000 строк)
if [[ -f "${LOG_DIR}/sync.log" ]]; then
    tail -1000 "${LOG_DIR}/sync.log" > "${LOG_DIR}/sync.log.tmp" && mv "${LOG_DIR}/sync.log.tmp" "${LOG_DIR}/sync.log"
fi

exit 0
