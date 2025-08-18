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
sudo mkdir -p /var/www/html/data  # Для статических файлов

# 8. Настройка прав для статических файлов nginx
echo "🔐 Настройка прав для статических файлов nginx..."
# nginx:alpine использует UID:GID 101:101 по умолчанию, устанавливаем совместимые права
sudo chown -R 101:101 /var/www/html/data
sudo chmod -R 755 /var/www/html/data

# 9. Настройка UFW firewall
echo "🔥 Настройка UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5050/tcp  # FLOWISE (Пример порта приложения)
sudo ufw --force enable

# 10. Настройка Fail2ban
echo "🛡️ Настройка Fail2ban..."
echo "📝 Создание файла /etc/fail2ban/jail.local для защиты SSH..."
sudo bash -c 'cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600  # Время блокировки IP в секундах (здесь 1 час)
findtime = 600  # Период времени для учета неудачных попыток (здесь 10 минут)
EOF'

# Включаем, запускаем и перезапускаем сервис для применения конфигурации
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl restart fail2ban

# 11. Проверка статуса
echo ""
echo "✅ Настройка сервера завершена!"
echo ""
echo "📊 Статус Docker:"
sudo systemctl status docker --no-pager | grep "Active:"
echo ""
echo "📊 Статус Fail2ban:"
sudo systemctl status fail2ban --no-pager | grep "Active:"
echo ""
echo "📊 UFW статус:"
sudo ufw status numbered
echo ""
echo "⚠️  Не забудьте перелогиниться (или выполнить 'newgrp docker'), чтобы изменения в правах пользователя вступили в силу!"