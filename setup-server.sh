#!/bin/bash
# setup-server.sh - Скрипт начальной настройки сервера без Docker Swarm

# 1. Обновление системы
echo "📦 Обновление системы..."
sudo apt update && sudo apt upgrade -y
sudo apt install htop

# 2. Установка необходимых пакетов
echo "📦 Установка необходимых пакетов..."
sudo apt install -y \
    curl \
    wget \
    htop \
    ncdu \
    net-tools \
    jq \
    apache2-utils \
    ufw \
    fail2ban \
    git

# 3. Установка Docker
echo "🐳 Установка Docker..."
if ! command -v docker &> /dev/null
then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
else
    echo "Docker уже установлен."
fi

# 4. Добавление текущего пользователя в группу docker
echo "👤 Добавление пользователя $USER в группу docker..."
sudo usermod -aG docker $USER

# 5. Настройка Docker daemon
echo "⚙️ Настройка Docker daemon..."
sudo bash -c 'cat > /etc/docker/daemon.json << EOF
{
  "dns": ["8.8.8.8", "1.1.1.1"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF'

# 6. Перезапуск и включение автозапуска Docker
echo "🚀 Перезапуск и включение Docker..."
sudo systemctl restart docker
sudo systemctl enable docker

# 7. Создание директорий для проекта
echo "📁 Создание директорий..."
sudo mkdir -p /root/ai_project/
sudo mkdir -p /root/ai_project/logs  # Для синхронизации логов Traefik
sudo mkdir -p /var/www/html/data  # Для статических файлов

# 8. Настройка прав для директорий проекта
echo "🔐 Настройка прав для директорий проекта..."
# Статические файлы nginx - права 777 для записи из Node-RED контейнера
sudo chown -R 101:101 /var/www/html/data
sudo chmod -R 777 /var/www/html/data

echo "📁 Папка /var/www/html/data настроена с правами 777 для Node-RED файлов"

# Права для папки логов синхронизации (доступ для fail2ban)
sudo chown -R root:root /root/ai_project/logs
sudo chmod -R 755 /root/ai_project/logs

# 9. Настройка UFW firewall
echo "🔥 Настройка UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5050/tcp  # FLOWISE (Пример порта приложения)
sudo ufw allow 7040/tcp  # lightrag
sudo ufw allow 8333/tcp  # ChronaDB API
sudo ufw --force enable

# 10. Настройка Fail2ban с расширенной защитой
echo "🛡️ Настройка Fail2ban с защитой веб-сервисов..."

# Создание фильтра для общих атак через Traefik
echo "📝 Создание фильтра traefik-custom.conf..."
sudo bash -c 'cat > /etc/fail2ban/filter.d/traefik-custom.conf <<EOF
# Traefik Custom Authentication Filter for AI Project
# Detects HTTP authentication failures and attack patterns

[Definition]

# Match authentication failures (401, 403) and suspicious 404s
failregex = ^<HOST> - .* "(GET|POST|PUT|DELETE|HEAD|OPTIONS) .* HTTP/[12]\.[01]" (401|403|404) .*$
            ^<HOST> - .* "(GET|POST|HEAD) .*\.(php|asp|jsp|cgi|pl)" .* 404 .*$
            ^<HOST> - .* "(GET|POST|HEAD) .*(admin|login|wp-admin|wp-login|phpmyadmin|admin\.php)" .* (401|403|404) .*$
            ^<HOST> - .* "(GET|POST|HEAD) .*(\.env|config|backup|sql)" .* 404 .*$

# Ignore legitimate requests
ignoreregex = ^<HOST> - .* "(GET|POST) .* HTTP/[12]\.[01]" (200|301|302|304) .*$

[Init]
maxlines = 10
datepattern = ^%%d/%%b/%%Y:%%H:%%M:%%S
EOF'

# Создание фильтра для защиты Node-RED
echo "📝 Создание фильтра traefik-nodered.conf..."
sudo bash -c 'cat > /etc/fail2ban/filter.d/traefik-nodered.conf <<EOF
# Node-RED Authentication Filter
# Specifically targets Node-RED authentication endpoints and admin panel access

[Definition]

# Node-RED specific authentication failures
failregex = ^<HOST> - .* "POST /auth/token HTTP/[12]\.[01]" (401|403) .*$
            ^<HOST> - .* "(GET|POST) /auth/.* HTTP/[12]\.[01]" (401|403) .*$
            ^<HOST> - .* "(GET|POST) /admin.* HTTP/[12]\.[01]" (401|403) .*$
            ^<HOST> - .* "(GET|POST) /settings.* HTTP/[12]\.[01]" (401|403) .*$
            ^<HOST> - .* "(GET|POST) .* HTTP/[12]\.[01]" (401|403) .*nodered.*$

# Multiple rapid requests to Node-RED endpoints (potential brute force)
            ^<HOST> - .* "(GET|POST) /(red|admin|auth|settings|flows) .* HTTP/[12]\.[01]" .*$

# Ignore successful authentication
ignoreregex = ^<HOST> - .* "POST /auth/token HTTP/[12]\.[01]" 200 .*$
              ^<HOST> - .* "(GET|POST) .* HTTP/[12]\.[01]" (200|304) .*$

[Init]
maxlines = 5
datepattern = ^%%d/%%b/%%Y:%%H:%%M:%%S
EOF'

# Создание фильтра для защиты Flowise AI
echo "📝 Создание фильтра traefik-flowise.conf..."
sudo bash -c 'cat > /etc/fail2ban/filter.d/traefik-flowise.conf <<EOF
# Flowise AI Authentication Filter
# Protects Flowise AI admin panel and API endpoints on port 5050

[Definition]

# Flowise authentication failures (port 5050 specific)
failregex = ^<HOST> - .* "(GET|POST|PUT|DELETE) .*:5050.* HTTP/[12]\.[01]" (401|403|404) .*$
            ^<HOST> - .* "(GET|POST) .* HTTP/[12]\.[01]" (401|403) .*flowise.*$
            ^<HOST> - .* "(GET|POST) /(api/v1/chatflows|api/v1/credentials|api/v1/tools).* HTTP/[12]\.[01]" (401|403) .*$
            ^<HOST> - .* "(GET|POST) /login.* HTTP/[12]\.[01]" (401|403) .*$

# Detect scanning attempts on Flowise endpoints
            ^<HOST> - .* "(GET|POST) /(admin|dashboard|config|api).* HTTP/[12]\.[01]" 404 .*flowise.*$

# Multiple requests to Flowise in short time (potential attack)
            ^<HOST> - .* "(GET|POST) .* HTTP/[12]\.[01]" .* .*flowise.*$ 

# Ignore successful Flowise requests
ignoreregex = ^<HOST> - .* "(GET|POST) .* HTTP/[12]\.[01]" (200|301|302|304) .*flowise.*$

[Init] 
maxlines = 5
datepattern = ^%%d/%%b/%%Y:%%H:%%M:%%S
EOF'

# Создание расширенной конфигурации jail.local
echo "📝 Создание расширенного файла /etc/fail2ban/jail.local..."
sudo bash -c 'cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600  # Время блокировки IP в секундах (здесь 1 час)
findtime = 600  # Период времени для учета неудачных попыток (здесь 10 минут)

# ==============================================
# TRAEFIK PROTECTION - AI PROJECT SECURITY
# ==============================================

[traefik-general]
enabled = true
port = http,https
filter = traefik-custom
logpath = /root/ai_project/logs/access.log
maxretry = 10
bantime = 7200   # 2 hours ban for general attacks
findtime = 300   # 5 minutes window
action = %(action_mwl)s

[nodered-auth]
enabled = true
port = 443
filter = traefik-nodered
logpath = /root/ai_project/logs/access.log
maxretry = 3
bantime = 14400  # 4 hours ban for Node-RED attacks
findtime = 600   # 10 minutes window
action = %(action_mwl)s

[flowise-auth]
enabled = true
port = 5050
filter = traefik-flowise
logpath = /root/ai_project/logs/access.log
maxretry = 3
bantime = 14400  # 4 hours ban for Flowise attacks  
findtime = 600   # 10 minutes window
action = %(action_mwl)s
EOF'

# Включаем, запускаем и перезапускаем сервис для применения конфигурации
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl restart fail2ban

# 11. Создание скрипта автосинхронизации логов
echo "🔄 Создание скрипта автосинхронизации логов Traefik..."
sudo bash -c 'cat > /root/ai_project/sync-logs.sh <<'"'"'EOF'"'"'
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
    echo "[$(date '"'"'+%Y-%m-%d %H:%M:%S'"'"')] $1" >> "${LOG_DIR}/sync.log"
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
EOF'

# Установка прав на выполнение
sudo chmod +x /root/ai_project/sync-logs.sh

# 12. Настройка автосинхронизации через cron
echo "⏰ Настройка автосинхронизации логов через cron..."
(sudo crontab -l 2>/dev/null; echo "# AI Project - Traefik Logs Auto-Sync for Fail2ban"; echo "# Синхронизирует логи каждые 2 минуты для обеспечения актуальности данных для fail2ban"; echo "*/2 * * * * /root/ai_project/sync-logs.sh >/dev/null 2>&1"; echo ""; echo "# Ротация логов синхронизации каждый день в 03:00"; echo "0 3 * * * find /root/ai_project/logs -name 'sync.log' -mtime +7 -delete >/dev/null 2>&1") | sudo crontab -

# 13. Проверка статуса и итоговая информация
echo ""
echo "✅ Настройка сервера с расширенной защитой завершена!"
echo ""
echo "📊 Статус Docker:"
sudo systemctl status docker --no-pager | grep "Active:"
echo ""
echo "📊 Статус Fail2ban с защитой веб-сервисов:"
sudo systemctl status fail2ban --no-pager | grep "Active:"
if command -v fail2ban-client &> /dev/null; then
    echo "🛡️ Активные jail:"
    sudo fail2ban-client status 2>/dev/null | grep "Jail list:" || echo "   SSH защита настроена"
fi
echo ""
echo "📊 UFW статус:"
sudo ufw status numbered
echo ""
echo "📊 Cron автосинхронизация:"
sudo crontab -l | grep -c "sync-logs.sh" >/dev/null && echo "✅ Автосинхронизация логов настроена (каждые 2 минуты)" || echo "❌ Автосинхронизация не настроена"
echo ""
echo "🎯 Что настроено:"
echo "   ✅ Docker с ограничением логов"
echo "   ✅ UFW firewall (порты: 22, 80, 443, 5050)"
echo "   ✅ Fail2ban с защитой SSH"
echo "   ✅ Расширенная защита fail2ban для портов 443 и 5050"
echo "   ✅ Автосинхронизация логов Traefik для fail2ban"
echo "   ✅ Директории проекта с корректными правами"
echo "   ✅ Папка /var/www/html/data с правами 777 для Node-RED"
echo ""
echo "🔧 Следующие шаги:"
echo "   1. Перелогиньтесь: 'exit' затем 'ssh root@server'"
echo "   2. Настройте .env файл с вашими данными"
echo "   3. Запустите: './ssl-check.sh' для проверки домена"
echo "   4. При успехе: 'docker compose up -d' для запуска сервисов"
echo ""
echo "📋 Полезные команды:"
echo "   sudo fail2ban-client status              # Статус защиты"
echo "   tail -f /root/ai_project/logs/sync.log   # Мониторинг синхронизации"
echo "   /root/ai_project/sync-logs.sh            # Ручная синхронизация"
echo ""
echo "⚠️  ВАЖНО: Не забудьте перелогиниться для применения изменений в правах пользователя!"