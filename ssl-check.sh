#!/bin/bash

# SSL Domain Check Script
# Проверяет готовность домена для получения SSL сертификата

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Получаем текущую директорию скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="$SCRIPT_DIR/.env"

# Функция для чтения переменных из .env
load_env() {
    if [ -f "$ENV_FILE" ]; then
        # Читаем только строки вида KEY=VALUE, игнорируем комментарии
        while IFS= read -r line; do
            # Пропускаем пустые строки и комментарии
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Экспортируем только если строка содержит =
            if [[ "$line" =~ ^[^=]+=[^=]*$ ]]; then
                export "$line"
            fi
        done < "$ENV_FILE"
    else
        echo -e "${RED}❌ Файл .env не найден!${NC}"
        exit 1
    fi
}

echo -e "${BLUE}🔍 SSL Domain Check для ${DOMAIN}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Загружаем переменные окружения
load_env

# Проверяем наличие домена
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ DOMAIN не задан в .env файле${NC}"
    exit 1
fi

if [ -z "$ACME_EMAIL" ]; then
    echo -e "${RED}❌ ACME_EMAIL не задан в .env файле${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Проверяем домен: ${GREEN}$DOMAIN${NC}"
echo -e "${YELLOW}📧 Email: ${GREEN}$ACME_EMAIL${NC}"
echo ""

# Установка зависимостей
echo -e "${BLUE}📦 Установка certbot...${NC}"
if ! command -v snap >/dev/null 2>&1; then
    echo -e "${YELLOW}⚙️  Установка snapd...${NC}"
    sudo apt-get update -qq
    sudo apt-get install snapd -y -qq
fi

if ! snap list | grep -q certbot; then
    echo -e "${YELLOW}⚙️  Установка certbot...${NC}"
    sudo snap install --beta certbot --classic
else
    echo -e "${GREEN}✅ Certbot уже установлен${NC}"
fi

echo ""
echo -e "${BLUE}🧪 Выполняем dry-run проверку домена...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Проверяем есть ли запущенный Traefik на порту 80
if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q ":80->80"; then
    echo -e "${YELLOW}⚠️  Обнаружен запущенный Traefik на порту 80${NC}"
    echo -e "${BLUE}🔄 Временно останавливаем контейнеры для проверки...${NC}"
    docker compose down
    RESTART_SERVICES=true
else
    RESTART_SERVICES=false
fi

# Проверка домена (standalone режим)
if sudo certbot certonly --dry-run --standalone \
  --email "$ACME_EMAIL" \
  -d "$DOMAIN" \
  --agree-tos --non-interactive --quiet; then
  
    echo ""
    echo -e "${GREEN}✅ ПРОВЕРКА ДОМЕНА ПРОШЛА УСПЕШНО!${NC}"
    echo -e "${GREEN}🎉 Домен $DOMAIN корректно настроен для SSL${NC}"
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}✅ ДОМЕН ГОТОВ ДЛЯ ПОЛУЧЕНИЯ SSL СЕРТИФИКАТОВ!${NC}        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}    Запускаем все сервисы с автоматическим SSL:          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}    ${GREEN}docker compose up -d${NC}                               ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Проверяем нужно ли восстановить сервисы или запросить запуск
    if [ "$RESTART_SERVICES" = true ]; then
        echo -e "${BLUE}🚀 Восстанавливаем остановленные сервисы...${NC}"
        docker compose up -d
        echo ""
        echo -e "${GREEN}✅ Сервисы восстановлены!${NC}"
        echo -e "${YELLOW}⏳ Подождите 2-3 минуты для получения SSL сертификатов...${NC}"
        echo ""
        echo -e "${BLUE}🌐 Ваши сервисы доступны:${NC}"
        echo -e "   └─ Node-RED: ${GREEN}https://$DOMAIN${NC}"
        echo -e "   └─ Flowise:  ${GREEN}https://$DOMAIN:5050${NC}"
    else
        # Спрашиваем пользователя о запуске
        read -p "Запустить все сервисы сейчас? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}🚀 Запускаем все сервисы...${NC}"
            docker compose up -d
            echo ""
            echo -e "${GREEN}✅ Сервисы запущены!${NC}"
            echo -e "${YELLOW}⏳ Подождите 2-3 минуты для получения SSL сертификатов...${NC}"
            echo ""
            echo -e "${BLUE}🌐 Ваши сервисы будут доступны:${NC}"
            echo -e "   └─ Node-RED: ${GREEN}https://$DOMAIN${NC}"
            echo -e "   └─ Flowise:  ${GREEN}https://$DOMAIN:5050${NC}"
        else
            echo -e "${YELLOW}ℹ️  Для запуска выполните: ${BLUE}docker compose up -d${NC}"
        fi
    fi
    
else
    echo ""
    echo -e "${RED}❌ ПРОВЕРКА ДОМЕНА НЕ ПРОЙДЕНА${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Возможные проблемы:${NC}"
    echo -e "   1. ${RED}DNS${NC} домена $DOMAIN не указывает на этот сервер"
    echo -e "   2. ${RED}Порт 80${NC} заблокирован файрволом"
    echo -e "   3. ${RED}Домен${NC} не существует или недоступен"
    echo ""
    echo -e "${BLUE}🔍 Проверьте:${NC}"
    echo -e "   └─ nslookup $DOMAIN"
    echo -e "   └─ curl -I http://$DOMAIN"
    echo -e "   └─ sudo ufw status"
    echo ""
    
    # Восстанавливаем сервисы если они были остановлены
    if [ "$RESTART_SERVICES" = true ]; then
        echo -e "${BLUE}🔄 Восстанавливаем остановленные сервисы...${NC}"
        docker compose up -d
        echo -e "${GREEN}✅ Сервисы восстановлены${NC}"
        echo ""
    fi
    
    exit 1
fi