# 🚀 AI Project - Полное руководство по развертыванию
**v2.5 - Enhanced Security Edition**

## 📋 Содержание
- [Технологический стек](#-технологический-стек)
- [Архитектура системы](#-архитектура-системы)
- [Структура сервисов](#-структура-сервисов)
- [Предварительные требования](#-предварительные-требования)
- [Пошаговое развертывание](#-пошаговое-развертывание)
- [Настройка SSL](#-настройка-ssl)
- [🛡️ Система безопасности](#-система-безопасности)
- [Проверка и мониторинг](#-проверка-и-мониторинг)
- [Управление сервисами](#-управление-сервисами)
- [Устранение проблем](#-устранение-проблем)

---

## 🛠 Технологический стек

### 🐳 Контейнеризация и оркестрация:
- **Docker** - контейнеризация приложений
- **Docker Compose** - оркестрация многоконтейнерных приложений
- **Traefik v3.0** - реверс-прокси и балансировщик нагрузки

### 🌐 Веб-инфраструктура:
- **Nginx Alpine** - веб-сервер для статических файлов
- **Let's Encrypt** - автоматические SSL сертификаты
- **HTTP/HTTPS редиректы** - автоматическое перенаправление

### 🗄️ Базы данных:
- **MySQL 8.0** - основная реляционная БД
- **Redis 7 Alpine** - кэш и сессии
- **ChromaDB** - векторная база данных для AI

### 🤖 AI и автоматизация:
- **Node-RED** - visual programming для IoT и автоматизации
- **Flowise AI** - low-code AI workflows и чатботы
- **LightRAG** - Knowledge Graph & RAG система для работы с документами
- **Telegram Bot API** - интеграция с Telegram

### 📊 Управление и мониторинг:
- **phpMyAdmin** - веб-интерфейс для MySQL
- **Traefik Dashboard** - мониторинг прокси
- **Docker Logs** - централизованное логирование

### 🔐 Безопасность:
- **UFW Firewall** - сетевая защита (порты 22, 80, 443, 5050)
- **Fail2ban Enhanced** - расширенная защита от атак
  - SSH брутфорс защита
  - Node-RED админ-панель защита (порт 443)
  - Flowise AI защита (порт 5050)
  - Автоматическая детекция веб-атак
- **SSL/TLS шифрование** - Let's Encrypt сертификаты
- **Автосинхронизация логов** - для real-time мониторинга атак

---

## 🏗 Архитектура системы

```
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                ┌─────▼──────┐
                │   TRAEFIK  │ ◄─── SSL Termination
                │  (Proxy)   │      Load Balancer
                └─────┬──────┘      Port 80,443,5050,7040,8333
                      │
        ┌─────────────┼──────────────┼─────────────┼────────────┐
        │             │              │             │            │
   ┌────▼────┐   ┌────▼────┐   ┌─────▼─────┐ ┌────▼────┐ ┌─────▼──────┐
   │Node-RED │   │Flowise  │   │ LightRAG  │ │phpMyAdmin│ │ Chroma-API │
   │:443     │   │:5050    │   │ :7040     │ │/phpmyadmin│ │   :8333    │
   └────┬────┘   └────┬────┘   └─────┬─────┘ └────┬────┘ └─────┬──────┘
        │             │              │             │            │
        └─────────────┼──────────────┼─────────────┼────────────┘
                      │                                         │
            ┌─────────▼──────────┐                             │
            │   INTERNAL NETWORK │                             │
            │                    │                             │
   ┌────────┼──────────┼─────────┼─────────┬───────────────────┘
   │        │          │         │         │
┌──▼──┐ ┌──▼───┐ ┌─────▼──┐ ┌────▼───┐ ┌──▼──┐
│MySQL│ │Redis │ │ChromaDB│ │ Nginx  │ │Data │
│:3306│ │:6379 │ │:8000   │ │Static  │ │Vol. │
└─────┘ └──────┘ └────▲───┘ └────────┘ └─────┘
                      │
                      │ REST API
                      │
                ┌─────┴──────┐
                │ Chroma-API │ (internal network access)
                │   :3010    │
                └────────────┘
```

### 🔄 Потоки данных:
1. **Пользователи** → **Traefik** → **Сервисы**
2. **Node-RED** ↔ **MySQL** (боты, логи)
3. **Flowise** ↔ **ChromaDB** (векторы, AI память)
4. **Chroma-API** ↔ **ChromaDB** (REST API для векторной БД)
5. **LightRAG** ↔ **Внутреннее хранилище** (графы знаний, RAG)
6. **Redis** ↔ **Все сервисы** (кэш, сессии)
7. **Nginx** → **Статические файлы** (`/var/www/html/data`)
8. **Node-RED** → **Публичные файлы** (`/data/public/` → `https://domain.com/data/`)
9. **Внешний мир** → **Chroma-API (HTTPS:8333)** → **ChromaDB** (API доступ к векторам)

### 📁 Структура проекта:

```
ai_project/                              # 📂 Корневая папка проекта
├── 📄 README.md                         # Главное руководство по развертыванию  
├── 📄 .env.example                      # Шаблон переменных окружения
├── 📄 .env                              # Реальные переменные (НЕ в git!)
├── 📄 .gitignore                        # Исключения для git
├── 📄 docker compose.yml                # Конфигурация всех сервисов
├──
├── 🛠️ setup-server.sh                   # Скрипт начальной настройки сервера
├── 🛠️ ssl-check.sh                      # Быстрая проверка домена для SSL
├──
├── 📁 traefik/                          # Конфигурация реверс-прокси
│   └── 📄 traefik.yml                   # Основной конфиг SSL
├──
├── 📁 nginx/                            # Конфигурация веб-сервера
│   └── 📄 default.conf                  # Настройки для статических файлов
├──
├── 📁 chroma-api/                       # REST API для ChromaDB
│   ├── 📄 Dockerfile                    # Docker образ для Chroma-API
│   ├── 📄 requirements.txt              # Python зависимости
│   ├── 📄 app.py                        # Flask приложение (создание app)
│   ├── 📄 routes.py                     # API endpoints (с проверкой токена)
│   ├── 📄 chroma_utils.py               # Утилиты для работы с ChromaDB
│   ├── 📄 readers.py                    # Чтение файлов (txt, pdf, docx, csv, json)
│   ├── 📄 wsgi.py                       # WSGI entry point для Gunicorn
│   └── 📄 __init__.py                   # Python package marker
├──
├── 📁 mysql_init/                       # Инициализация базы данных
│   └── 📄 init.sql                      # SQL скрипт создания таблиц
├──
├── 📁 flows/                            # Конфигурации flows (БЕЗ credentials)
│   ├── 📄 README.md                     # Документация по работе с flows
│   ├── 📁 node-red/                     # Node-RED flows экспорт
│   ├── 📁 flowise/                      # Flowise chatflows экспорт
│   └── 📁 templates/                    # Шаблоны для быстрого старта
├──
├── 📁 letsencrypt/                      # SSL сертификаты Let's Encrypt
│   └── 📄 acme.json                     # Файл хранения сертификатов
├──
├── 📁 certs/                            # Дополнительные SSL сертификаты
├──
└── 📄 bots.sql                          # Дамп базы данных (пример структуры)

# Внешние директории (создаются автоматически)
/var/www/html/data/                      # 📁 Статические файлы для Nginx
```

### 📊 Типы файлов и их назначение:

#### 🔧 **Конфигурационные файлы:**
- **docker compose.yml** - описание всех сервисов и их взаимосвязей
- **traefik/traefik.yml** - настройки прокси, SSL, маршрутизация
- **nginx/default.conf** - конфигурация веб-сервера для статики
- **.env** - переменные окружения (пароли, домены, API ключи)

#### 🧠 **API сервисы:**
- **chroma-api/app.py** - Flask приложение для REST API к ChromaDB
- **chroma-api/routes.py** - API endpoints с токен-аутентификацией
- **chroma-api/chroma_utils.py** - Singleton подключение к ChromaDB
- **chroma-api/readers.py** - Обработка файлов (pdf, docx, txt, csv, json)
- **chroma-api/Dockerfile** - Docker образ с health check
- **chroma-api/requirements.txt** - Python зависимости

#### 🛠️ **Скрипты автоматизации:**
- **setup-server.sh** - подготовка сервера (см. детали ниже)
- **ssl-check.sh** - проверка домена перед получением SSL

#### 📚 **Документация:**
- **README.md** - полное руководство по развертыванию
- **flows/README.md** - работа с Node-RED/Flowise flows

#### 💾 **Данные и состояние:**
- **letsencrypt/acme.json** - SSL сертификаты (автообновляемые)
- **mysql_init/init.sql** - начальная структура БД
- **flows/** - экспортированные конфигурации (БЕЗ паролей)

#### 🔐 **Безопасность:**
- **.gitignore** - исключает credentials, сертификаты, данные
- **.env.example** - безопасный шаблон без реальных паролей

### 🎯 **Принципы организации:**
1. **Разделение конфигурации и данных** - config в git, данные в volumes
2. **Безопасность по умолчанию** - все секреты исключены из git
3. **Автоматизация** - скрипты для всех рутинных операций  
4. **Документированность** - каждый компонент имеет README
5. **Модульность** - каждый сервис в отдельной папке

### 🔧 **Детали setup-server.sh:**

Расширенный скрипт начальной настройки сервера (331 строка) выполняет полную подготовку системы безопасности:

```bash
# 1. 📦 Обновление системы и установка пакетов
sudo apt update && sudo apt upgrade -y
# Установка: curl, wget, htop, ncdu, net-tools, jq, apache2-utils, ufw, fail2ban, git

# 2. 🐳 Установка и настройка Docker
# - Официальный скрипт установки Docker
# - Добавление пользователя в группу docker
# - Настройка daemon.json (лимиты логов: 100MB, 3 файла)
# - Автозапуск службы Docker

# 3. 📁 Создание директорий проекта
# - /root/ai_project/ - корневая папка проекта
# - /root/ai_project/logs/ - логи для fail2ban
# - /var/www/html/data - статические файлы Nginx
# - Настройка прав: 755 для публичных директорий

# 4. 🔥 Настройка UFW Firewall
# - Политика по умолчанию: deny incoming, allow outgoing
# - Открытие портов: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5050 (Flowise)
# - Принудительное включение с --force

# 5. 🛡️ Создание кастомных фильтров Fail2ban
# /etc/fail2ban/filter.d/traefik-custom.conf - общие веб-атаки
# /etc/fail2ban/filter.d/traefik-nodered.conf - защита Node-RED
# /etc/fail2ban/filter.d/traefik-flowise.conf - защита Flowise AI

# 6. 🎯 Настройка jail конфигурации
# /etc/fail2ban/jail.local - 4 активных jail:
# - sshd: 5 попыток/10 мин, бан 1 час
# - traefik-general: 10 попыток/5 мин, бан 2 часа
# - nodered-auth: 3 попытки/10 мин, бан 4 часа  
# - flowise-auth: 3 попытки/10 мин, бан 4 часа

# 7. 🔄 Создание скрипта синхронизации логов
# /root/ai_project/sync-logs.sh:
# - Копирование логов из Docker контейнера Traefik
# - Автоматическая перезагрузка всех fail2ban jail
# - Логирование процесса синхронизации
# - Права выполнения: chmod +x

# 8. ⏰ Настройка cron автоматизации
# Добавление в crontab:
# */2 * * * * /root/ai_project/sync-logs.sh >/dev/null 2>&1
# Синхронизация каждые 2 минуты для real-time мониторинга

# 9. 🚀 Запуск служб безопасности
# - systemctl enable fail2ban
# - systemctl start fail2ban
# - systemctl status fail2ban (проверка)

# 10. ✅ Комплексная проверка результата
# - Статус Docker службы
# - Статус Fail2ban службы
# - Проверка активных jail: fail2ban-client status
# - Список правил UFW firewall
# - Проверка cron задач
# - Проверка создания директорий и файлов
```

**Результат выполнения (Enhanced Security Setup):**
- ✅ Обновленная система с полным пакетом безопасности
- ✅ Настроенный Docker с оптимизированными логами
- ✅ Многоуровневый firewall (UFW + Fail2ban)
- ✅ Расширенная защита от атак:
  - SSH брутфорс (5 попыток → 1 час бан)
  - Веб-сканирование (10 попыток → 2 часа бан)
  - Node-RED админ-панель (3 попытки → 4 часа бан)
  - Flowise AI платформа (3 попытки → 4 часа бан)
- ✅ Автоматическая синхронизация логов (каждые 2 минуты)
- ✅ Real-time мониторинг атак через cron
- ✅ Подготовленные директории с правильными правами
- ✅ Готовность к немедленному развертыванию Docker сервисов

---

## 🏢 Структура сервисов

### 🌐 Фронтенд сервисы (публично доступны):

#### 📡 **Traefik** (`service_traefik`)
- **Порты**: 80, 443, 5050, 8082
- **Функции**: SSL терминация, маршрутизация, балансировка
- **Домены**: 
  - `domain.com` → Node-RED
  - `domain.com:5050` → Flowise
  - `domain.com/phpmyadmin` → phpMyAdmin
  - `domain.com/data` → Статические файлы

#### 🔴 **Node-RED** (`service_nodered`)
- **Внутренний порт**: 1880
- **Внешний доступ**: `https://domain.com:443`
- **Данные**: Docker volume `nodered_data` + `/data/public/` для файлов
- **Публичные файлы**: `/data/public/` → `https://domain.com/data/`
- **Аутентификация**: ✅ Защищен паролем из `.env`
- **Назначение**: Автоматизация, IoT, Telegram боты

#### 🤖 **Flowise AI** (`service_flowise`)
- **Внутренний порт**: 3000
- **Внешний доступ**: `https://domain.com:5050`
- **Данные**: Docker volume `flowise_data`
- **Назначение**: AI workflow, чатботы, векторный поиск
- **Подключение к ChromaDB**: `http://service_chroma:8000` (прямой доступ к векторной БД)

#### 🧠 **LightRAG** (`service_lightrag`)
- **Внутренний порт**: 9621
- **Внешний доступ**: `https://domain.com:7040`
- **Внутренний URL**: `http://lightrag:9621` или `http://service_lightrag:9621`
- **Данные**: Docker volume `lightrag_storage` + bind mounts для inputs/tiktoken
- **Аутентификация**: ✅ JWT токены (AUTH_ACCOUNTS, TOKEN_SECRET из `.env`)
- **API документация**: `https://domain.com:7040/docs` (Swagger/OpenAPI)
- **Назначение**: Knowledge Graph построение, RAG (Retrieval Augmented Generation), работа с документами
- **Использование из других контейнеров**:
  ```bash
  # Из Node-RED, Flowise или любого другого сервиса:
  curl http://lightrag:9621/api/endpoint
  # или
  curl http://service_lightrag:9621/api/endpoint
  ```

#### 📊 **phpMyAdmin** (`service_phpmyadmin`)
- **Внутренний порт**: 80
- **Внешний доступ**: `https://domain.com/phpmyadmin`
- **Назначение**: Управление MySQL базами данных

#### 📁 **Nginx Static** (`service_nginx_static`)
- **Внутренний порт**: 80
- **Внешний доступ**: `https://domain.com/data/*`
- **Данные**: `/var/www/html/data` (bind mount)
- **Назначение**: Раздача статических файлов

### 💾 Backend сервисы (внутренняя сеть):

#### 🗄️ **MySQL** (`service_mysql`)
- **Внутренний порт**: 3306
- **Внешний порт**: 3306 (для внешних подключений)
- **Данные**: Docker volume `mysql_data` + инициализация из `mysql_init/`
- **База**: `bots` с таблицами для Telegram ботов

#### ⚡ **Redis** (`service_redis`)
- **Внутренний порт**: 6379
- **Внешний порт**: 6379
- **Данные**: Docker volume `redis_data`
- **Назначение**: Кэширование, сессии, очереди

#### 🧠 **ChromaDB** (`service_chroma`)
- **Внутренний порт**: 8000
- **Прямой доступ из Docker**: `http://service_chroma:8000` (для Flowise, Node-RED, LightRAG)
- **Внешний доступ**: Только через Chroma-API (security by design)
- **Данные**: Docker volume `chroma_data`
- **Назначение**: Векторная БД для AI/ML операций
- **Использование из Flowise**:
  ```yaml
  Chroma URL: http://service_chroma:8000
  Collection Name: flowise_collection
  ```

#### 🔌 **Chroma-API** (`service_chroma_api`)
- **Внутренний порт**: 3010
- **Внешний порт**: 8333 (HTTPS через Traefik)
- **Внешний доступ**: `https://your-domain.com:8333/api`
- **Внутренний доступ**: `http://service_chroma_api:3010/api`
- **Данные**: Подключение к `service_chroma:8000`
- **Назначение**: REST API для ChromaDB с токен-аутентификацией
- **Особенности**:
  - Health Check endpoint (`/health`)
  - Token-based authentication
  - Rate limiting (100 req/sec)
  - Support для txt, pdf, docx, csv, json файлов
  - Singleton connection pooling

---

## 🧠 LightRAG - Knowledge Graph & RAG система

**LightRAG** - это мощная система для работы с документами, построения графов знаний и Retrieval Augmented Generation (RAG).

### 📋 Основные возможности:

- **📄 Обработка документов** - загрузка и индексация текстовых документов
- **🕸️ Knowledge Graph** - автоматическое построение графов знаний из текста
- **🔍 RAG (Retrieval Augmented Generation)** - умный поиск и генерация ответов
- **🎯 Entity Extraction** - извлечение сущностей и связей
- **📊 Векторизация** - использует OpenAI embeddings для семантического поиска
- **🔐 JWT аутентификация** - защищенный доступ к API

### 🌐 Доступ к сервису:

**Внешний доступ (из браузера):**
```bash
https://your-domain.com:7040           # WebUI и API
https://your-domain.com:7040/docs      # Swagger документация
https://your-domain.com:7040/redoc     # ReDoc документация
```

**Внутренний доступ (из других Docker контейнеров):**
```bash
http://lightrag:9621                   # По имени сервиса
http://service_lightrag:9621           # По имени контейнера
```

### 🔑 Аутентификация:

LightRAG использует JWT токены для защиты API. Учетные данные хранятся в `.env`:

```bash
# В .env файле:
AUTH_ACCOUNTS=admin:your-password      # Формат: username:password
TOKEN_SECRET=your-secret-key-32chars   # Секретный ключ для JWT
```

**Получение токена:**
```bash
# Логин и получение JWT токена
curl -X POST https://your-domain.com:7040/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your-password"}'

# Ответ: {"access_token": "eyJ0eXAiOiJKV1QiLCJhb..."}
```

**Использование токена:**
```bash
# Запрос к API с токеном
curl https://your-domain.com:7040/api/endpoint \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhb..."
```

### 📌 Режимы поиска (Query Modes):

LightRAG поддерживает 6 режимов запросов для различных сценариев поиска информации:

#### **1. Naive (Наивный)**
- **Описание**: Performs a basic search without advanced techniques
- **Простыми словами**: Простой базовый поиск без использования продвинутых техник
- **Особенности**:
  - Не использует граф знаний
  - Самый быстрый режим
  - Подходит для простых запросов
- **Когда использовать**: Простые фактические вопросы, быстрый поиск

#### **2. Local (Локальный)**
- **Описание**: Focuses on context-dependent information
- **Простыми словами**: Фокусируется на контекстно-зависимой информации
- **Особенности**:
  - В этом режиме параметр `top_k` представляет количество **entities (сущностей)**
  - Использует локальный контекст вокруг найденных сущностей
  - Хорошо работает с конкретными объектами/персонами
- **Когда использовать**: Вопросы о конкретных людях, местах, объектах

#### **3. Global (Глобальный)**
- **Описание**: Utilizes global knowledge
- **Простыми словами**: Использует глобальные знания
- **Особенности**:
  - В этом режиме параметр `top_k` представляет количество **relationships (связей)**
  - Анализирует связи между сущностями
  - Работает с общими паттернами в данных
- **Когда использовать**: Вопросы о трендах, закономерностях, общих темах

#### **4. Hybrid (Гибридный)**
- **Описание**: Combines local and global retrieval methods
- **Простыми словами**: Комбинирует локальный и глобальный методы поиска
- **Особенности**:
  - Использует и entities, и relationships
  - Наиболее сбалансированный режим
  - Хороший баланс точности и скорости
- **Когда использовать**: **Рекомендуется по умолчанию** для большинства запросов

#### **5. Mix (Смешанный)**
- **Описание**: Integrates knowledge graph and vector retrieval
- **Простыми словами**: Интегрирует граф знаний и векторный поиск
- **Особенности**:
  - Комбинирует структурированные данные (граф) с векторным поиском
  - Наиболее полный режим
  - Более ресурсоемкий (медленнее)
- **Когда использовать**: Когда нужна максимальная полнота результатов

#### **6. Bypass**
- **Описание**: Режим без описания в официальной документации
- **Особенности**: Предположительно пропускает стандартную RAG-обработку
- **Когда использовать**: Специальные случаи (назначение неизвестно)

## 💡 Рекомендации по выбору режима

| Режим | Скорость | Точность | Сценарий использования |
|-------|----------|----------|------------------------|
| Naive | ⚡️⚡️⚡️⚡️⚡️ | ⭐️⭐️ | Быстрый поиск, простые вопросы |
| Local | ⚡️⚡️⚡️⚡️ | ⭐️⭐️⭐️ | Вопросы о конкретных сущностях |
| Global | ⚡️⚡️⚡️⚡️ | ⭐️⭐️⭐️ | Вопросы о связях и паттернах |
| Hybrid | ⚡️⚡️⚡️ | ⭐️⭐️⭐️⭐️ | Универсальный (рекомендуется) |
| Mix | ⚡️⚡️ | ⭐️⭐️⭐️⭐️⭐️ | Максимальная полнота |
| Bypass | ⚡️⚡️⚡️⚡️⚡️ | ❓ | Специальные случаи |

---

### 🔧 Использование из других сервисов:

#### Из Node-RED:
```javascript
// HTTP Request node
{
  "method": "POST",
  "url": "http://lightrag:9621/api/insert",
  "headers": {
    "Authorization": "Bearer YOUR_JWT_TOKEN",
    "Content-Type": "application/json"
  },
  "body": {
    "text": "Your document text here..."
  }
}
```

#### Из Flowise:
```javascript
// В Custom Tool или HTTP Request node
const response = await fetch('http://lightrag:9621/api/query', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_JWT_TOKEN',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    query: "What is machine learning?",
    mode: "hybrid"
  })
});
```

#### Из Python (внутри контейнера):
```python
import requests

# Получение токена
auth_response = requests.post(
    'http://lightrag:9621/auth/login',
    json={'username': 'admin', 'password': 'your-password'}
)
token = auth_response.json()['access_token']

# Запрос к API
headers = {'Authorization': f'Bearer {token}'}
response = requests.post(
    'http://lightrag:9621/api/query',
    headers=headers,
    json={'query': 'Explain RAG', 'mode': 'hybrid'}
)
print(response.json())
```

### 📂 Структура данных:

LightRAG хранит данные в нескольких местах:

```bash
lightrag/
├── data/
│   ├── inputs/          # Входные документы для обработки
│   ├── tiktoken/        # Кэш токенизатора OpenAI
│   └── rag_storage/     # Хранится в Docker volume (граф, векторы)
```

**Docker volumes:**
- `lightrag_storage` - основное хранилище графов знаний и индексов

### ⚙️ Конфигурация:

Все параметры настраиваются через `.env`:

```bash
# LightRAG настройки
SUMMARY_LANGUAGE=English              # Язык суммаризации
CHUNK_SIZE=1200                       # Размер чанков текста
CHUNK_OVERLAP_SIZE=200                # Перекрытие чанков
FORCE_LLM_SUMMARY_ON_MERGE=4          # LLM суммаризация
SUMMARY_MAX_TOKENS=30000              # Макс токенов для суммаризации

# OpenAI для embeddings
EMBEDDING_BINDING=openai
EMBEDDING_MODEL=text-embedding-3-large
EMBEDDING_BINDING_API_KEY=sk-your-key

# OpenAI для LLM
LLM_BINDING=openai
LLM_MODEL=gpt-4o-mini
LLM_BINDING_API_KEY=sk-your-key

# Производительность
MAX_ASYNC=12                          # Максимум асинхронных задач
MAX_PARALLEL_INSERT=3                 # Параллельные вставки
EMBEDDING_FUNC_MAX_ASYNC=24           # Асинхронность embeddings
EMBEDDING_BATCH_NUM=100               # Размер батча embeddings
```

### 🚀 Типичные сценарии использования:

1. **Загрузка документов** → `POST /api/insert`
2. **Поиск по документам** → `POST /api/query`
3. **Построение графа знаний** → автоматически при вставке
4. **RAG генерация ответов** → `POST /api/query` с mode="hybrid"

---

## 🧠 Chroma-API - REST API для ChromaDB

**Chroma-API** - это REST API сервис для работы с векторной базой данных ChromaDB, обеспечивающий простой интерфейс для хранения, поиска и управления документами с использованием векторных embeddings.

### 📋 Основные возможности:

- **📄 Загрузка документов** - поддержка txt, pdf, docx, csv, json файлов
- **📝 Загрузка JSON данных** - прямая загрузка структурированных данных
- **🔍 RAG запросы** - семантический поиск по документам с фильтрацией
- **📊 Управление коллекциями** - создание, просмотр, удаление коллекций
- **🗑️ Удаление документов** - гибкое удаление по метаданным
- **🔐 Безопасность** - токен-аутентификация для всех запросов
- **📈 Health Check** - мониторинг работоспособности API и ChromaDB
- **⚡ Rate Limiting** - защита от перегрузки (100 req/sec)

### 🌐 Доступ к сервису:

**Внешний доступ (из браузера/интернета):**
```bash
https://your-domain.com:8333/health      # Health Check
https://your-domain.com:8333/api         # API endpoint
```

**Внутренний доступ (из других Docker контейнеров):**
```bash
http://service_chroma_api:3010/health    # Health Check
http://service_chroma_api:3010/api       # API endpoint
```

**Альтернативный внутренний доступ:**
```bash
http://chroma-api:3010/health
http://chroma-api:3010/api
```

### 🔑 Аутентификация:

Chroma-API использует проверку токена через header `x-chroma-api-token`. Токен настраивается в файле `.env`:

```bash
# В .env файле:
CHROMA_API_TOKEN=your-secret-token-here
```

**Все запросы к `/api` endpoint требуют токен аутентификации. Без токена вернется ошибка 401.**

---

### 📚 API Endpoints

#### 1. 🏥 Health Check

**Проверка работоспособности API и подключения к ChromaDB**

**Локально (внутри Docker):**
```bash
# Из хост-системы
docker exec service_chroma_api curl http://localhost:3010/health

# Из другого контейнера
curl http://service_chroma_api:3010/health
```

**Из внешнего мира (через HTTPS):**
```bash
curl https://your-domain.com:8333/health
```

**Ответ:**
```json
{
  "status": "healthy",
  "service": "chroma-api",
  "chroma_connected": true
}
```

---

#### 2. 📝 Upsert JSON - Загрузка JSON данных

**Добавление структурированных данных в коллекцию**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "upsert_json",
    "collection_name": "my_collection",
    "json_data": "Your text data here",
    "metadata": {
      "source": "api",
      "category": "example"
    }
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "upsert_json",
    "collection_name": "my_collection",
    "json_data": "Your text data here",
    "metadata": {
      "source": "api",
      "category": "example"
    }
  }'
```

**Параметры:**
- `action`: "upsert_json" (обязательно)
- `collection_name`: имя коллекции (обязательно)
- `json_data`: текстовые данные или JSON объект (обязательно)
- `metadata`: метаданные для документа (опционально)
- `separate_chunks`: true/false - разделить на чанки (опционально)
- `openai_api_key`: API ключ OpenAI (опционально, по умолчанию из .env)
- `model_name`: модель для embeddings (опционально, по умолчанию из .env)

**Ответ:**
```json
{
  "status": "success",
  "added": 1,
  "ids": ["uuid-here"],
  "model_used": "text-embedding-3-large"
}
```

---

#### 3. 📄 Upsert - Загрузка файлов

**Загрузка и индексация файлов (txt, pdf, docx, csv, json)**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "upsert",
    "file_name": "https://example.com/document.pdf",
    "collection_name": "documents",
    "metadata": {
      "source": "web",
      "title": "Example Document"
    },
    "chunk_size": 1000,
    "chunk_overlap": 200
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "upsert",
    "file_name": "https://example.com/document.pdf",
    "collection_name": "documents",
    "metadata": {
      "source": "web",
      "title": "Example Document"
    }
  }'
```

**Параметры:**
- `action`: "upsert" (обязательно)
- `file_name`: URL или путь к файлу (обязательно)
- `collection_name`: имя коллекции (обязательно)
- `metadata`: метаданные (опционально)
- `chunk_size`: размер чанков текста (опционально, по умолчанию из .env)
- `chunk_overlap`: перекрытие чанков (опционально, по умолчанию из .env)
- `custom_separators`: кастомные разделители для чанков (опционально)

**Ответ:**
```json
{
  "status": "success",
  "added": 5,
  "ids": ["id1", "id2", "id3", "id4", "id5"],
  "model_used": "text-embedding-3-large"
}
```

---

#### 4. 🔍 Query - Поиск по коллекции

**Семантический поиск релевантных документов с фильтрацией**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "query",
    "collection_name": "my_collection",
    "query": "What is machine learning?",
    "n_results": 5,
    "filters": {
      "where": {
        "category": "example"
      }
    }
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "query",
    "collection_name": "my_collection",
    "query": "What is machine learning?",
    "n_results": 5
  }'
```

**Параметры:**
- `action`: "query" (обязательно)
- `collection_name`: имя коллекции (обязательно)
- `query`: поисковый запрос (обязательно)
- `n_results`: количество результатов (опционально, по умолчанию 4)
- `filters`: фильтры по метаданным (опционально)
  - `where`: фильтр по метаданным (например: `{"source": "api"}`)
  - `where_document`: фильтр по содержимому документа

**Ответ:**
```json
{
  "status": "success",
  "results": {
    "documents": ["Document 1 text", "Document 2 text"],
    "metadatas": [
      {"source": "api", "category": "example"},
      {"source": "web", "category": "example"}
    ],
    "distances": [0.25, 0.35],
    "ids": ["id1", "id2"],
    "model_used": "text-embedding-3-large"
  }
}
```

---

#### 5. 📊 Count - Подсчет документов

**Получение количества документов в коллекции**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "count",
    "collection_name": "my_collection"
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "count",
    "collection_name": "my_collection"
  }'
```

**Параметры:**
- `action`: "count" (обязательно)
- `collection_name`: имя коллекции (обязательно)

**Ответ:**
```json
{
  "status": "success",
  "count": 42
}
```

---

#### 6. 📋 Show Collection - Просмотр коллекции

**Получение всех документов из коллекции с фильтрацией**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "show_collection",
    "collection_name": "my_collection",
    "filters": {
      "where": {
        "source": "api"
      },
      "limit": 10
    }
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "show_collection",
    "collection_name": "my_collection",
    "filters": {
      "limit": 100
    }
  }'
```

**Параметры:**
- `action`: "show_collection" (обязательно)
- `collection_name`: имя коллекции (обязательно)
- `filters`: параметры фильтрации (опционально)
  - `where`: фильтр по метаданным
  - `limit`: максимальное количество результатов
  - `offset`: смещение для пагинации

**Ответ:**
```json
{
  "ids": ["id1", "id2", "id3"],
  "documents": ["Doc 1", "Doc 2", "Doc 3"],
  "metadatas": [
    {"source": "api"},
    {"source": "api"},
    {"source": "web"}
  ],
  "included": ["metadatas", "documents"]
}
```

---

#### 7. 🗑️ Delete File - Удаление документов

**Удаление документов по фильтрам метаданных**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "delete_file",
    "collection_name": "my_collection",
    "filters": {
      "where": {
        "source": "api",
        "category": "temporary"
      }
    }
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "delete_file",
    "collection_name": "my_collection",
    "filters": {
      "where": {
        "source": "temporary"
      }
    }
  }'
```

**Параметры:**
- `action`: "delete_file" (обязательно)
- `collection_name`: имя коллекции (обязательно)
- `filters`: фильтры для удаления (обязательно)
  - `where`: условия по метаданным
  - `ids`: конкретные ID документов

**Ответ:**
```json
{
  "status": "success",
  "deleted": 3,
  "ids": ["id1", "id2", "id3"]
}
```

---

#### 8. 🗂️ Delete Collection - Удаление коллекции

**Полное удаление коллекции со всеми документами**

**Локально:**
```bash
docker exec service_chroma_api curl -X POST http://localhost:3010/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "delete_collection",
    "collection_name": "old_collection"
  }'
```

**Из внешнего мира:**
```bash
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "delete_collection",
    "collection_name": "old_collection"
  }'
```

**Параметры:**
- `action`: "delete_collection" (обязательно)
- `collection_name`: имя коллекции для удаления (обязательно)

**Ответ:**
```json
{
  "status": "success",
  "message": "Collection old_collection deleted"
}
```

---

### ⚙️ Конфигурация:

Все параметры настраиваются через `.env`:

```bash
# ChromaDB подключение (внутренняя сеть Docker)
CHROMA_SERVER_HOST=service_chroma
CHROMA_SERVER_PORT=8000

# Настройки эмбеддингов
CHROMA_MODEL=text-embedding-3-large
CHROMA_DEFAULT_CHUNK_SIZE=1000
CHROMA_DEFAULT_CHUNK_OVERLAP=200

# Безопасность
CHROMA_API_TOKEN=your-secret-token-here

# OpenAI API для создания embeddings
OPENAI_API_KEY=sk-your-openai-key
```

### 🔒 Безопасность:

- **Токен-аутентификация**: Все запросы к `/api` требуют валидный токен
- **Rate Limiting**: 100 запросов/секунду (средняя), burst до 50 запросов
- **Compression**: Автоматическое сжатие JSON ответов
- **SSL/TLS**: Внешний доступ только через HTTPS
- **Internal Network**: ChromaDB доступен только внутри Docker сети

### 📊 Мониторинг:

**Проверка работоспособности:**
```bash
# Health check
curl https://your-domain.com:8333/health

# Логи контейнера
docker logs service_chroma_api -f

# Статус контейнера (включая healthcheck)
docker ps | grep chroma_api

# Детальная информация о health
docker inspect service_chroma_api | grep -A 10 Health
```

### 🚀 Примеры использования:

**1. Создание базы знаний:**
```bash
# Загрузить несколько документов
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "upsert",
    "file_name": "https://example.com/doc1.pdf",
    "collection_name": "knowledge_base"
  }'

# Проверить количество
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "count",
    "collection_name": "knowledge_base"
  }'
```

**2. RAG-поиск с фильтрацией:**
```bash
# Поиск только в документах определенной категории
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "query",
    "collection_name": "knowledge_base",
    "query": "Explain neural networks",
    "n_results": 3,
    "filters": {
      "where": {
        "category": "AI"
      }
    }
  }'
```

**3. Управление данными:**
```bash
# Удалить временные документы
curl -X POST https://your-domain.com:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: xxxxxxx" \
  -d '{
    "action": "delete_file",
    "collection_name": "knowledge_base",
    "filters": {
      "where": {
        "temporary": "true"
      }
    }
  }'
```

### 🔧 Использование из других сервисов:

**Из Node-RED:**
```javascript
// HTTP Request node
msg.url = "http://service_chroma_api:3010/api";
msg.method = "POST";
msg.headers = {
  "Content-Type": "application/json",
  "x-chroma-api-token": env.get("CHROMA_API_TOKEN")
};
msg.payload = {
  action: "query",
  collection_name: "my_docs",
  query: msg.payload.userQuestion,
  n_results: 5
};
return msg;
```

**Из Python (внутри Docker):**
```python
import requests
import os

def query_chroma(query_text, collection="documents"):
    url = "http://service_chroma_api:3010/api"
    headers = {
        "Content-Type": "application/json",
        "x-chroma-api-token": os.getenv("CHROMA_API_TOKEN")
    }
    payload = {
        "action": "query",
        "collection_name": collection,
        "query": query_text,
        "n_results": 5
    }

    response = requests.post(url, json=payload, headers=headers)
    return response.json()
```

**Из JavaScript/Flowise:**
```javascript
// Custom Function node
const response = await fetch('http://service_chroma_api:3010/api', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-chroma-api-token': process.env.CHROMA_API_TOKEN
  },
  body: JSON.stringify({
    action: 'query',
    collection_name: 'knowledge_base',
    query: $question,
    n_results: 5
  })
});

const data = await response.json();
return data.results.documents.join('\n\n');
```

### 📈 Производительность:

- **Workers**: 4 Gunicorn workers с 2 потоками каждый
- **Timeout**: 600 секунд для длительных операций
- **Connection Pooling**: Singleton подключение к ChromaDB
- **Batch Processing**: Поддержка параллельной обработки документов
- **Rate Limiting**: Защита от перегрузки

### ⚠️ Ограничения:

- **Размер файла**: 10 MB (настраивается в коде)
- **Разрешенные форматы**: txt, pdf, docx, csv, json
- **Безопасные пути**: Только разрешенные директории для локальных файлов
- **SSL verification**: Отключена для тестирования (можно включить в production)

---

## ⚠️ Предварительные требования

### 🖥 Серверные требования:
- **ОС**: Ubuntu 20.04+ / Debian 10+ / CentOS 8+
- **RAM**: минимум 2GB, рекомендуется 4GB+
- **CPU**: 2 ядра минимум
- **Диск**: 20GB+ свободного места
- **Сеть**: белый IP адрес

### 🌐 DNS настройки:
```bash
# Создайте A-записи в DNS:
domain.com        → IP_СЕРВЕРА
*.domain.com      → IP_СЕРВЕРА  # для поддоменов (опционально)
```

### 🔐 Доступы:
- **Root доступ** к серверу (sudo)
- **Порты 22, 80, 443, 5050** должны быть открыты
- **Email адрес** для Let's Encrypt уведомлений

---

## 🚀 Пошаговое развертывание

### 📥 Шаг 1: Подготовка сервера и установка базового ПО

```bash
# Подключитесь к своему серверу
ssh root@YOUR_SERVER_IP

# Скачайте проект
cd /root
git clone https://github.com/ProjectManager7/ai_project ai_project
cd ai_project

# Запустите скрипт начальной настройки
chmod +x setup-server.sh
./setup-server.sh
```

**Что делает `setup-server.sh`:**
- ✅ Обновляет систему и устанавливает необходимые пакеты
- ✅ Устанавливает Docker и Docker Compose
- ✅ Настраивает UFW firewall (порты 22, 80, 443, 5050)
- ✅ Настраивает Fail2ban для защиты SSH
- ✅ Создает директории проекта
- ✅ Устанавливает права для статических файлов nginx

### 🔄 Шаг 2: Перелогинивание

```bash
# ВАЖНО: Перелогиньтесь для применения Docker прав
exit
ssh root@YOUR_SERVER_IP

# Или выполните (если не хотите перелогиниваться):
newgrp docker
```

### ⚙️ Шаг 3: Настройка переменных окружения

```bash
cd /root/ai_project

# Отредактируйте .env файл
nano .env
```

**Обязательные изменения в `.env`:**
```bash
# Домен (ОБЯЗАТЕЛЬНО поменяйте!)
DOMAIN=your-domain.com

# Email для SSL сертификатов (ОБЯЗАТЕЛЬНО поменяйте!)
ACME_EMAIL=your-email@example.com

# Пароли (РЕКОМЕНДУЕТСЯ поменять)
NODE_RED_PASSWORD=your-secure-password          # Пароль для входа в Node-RED веб-интерфейс
FLOWISE_EMAIL=your-email@example.com            # Email для входа в Flowise
FLOWISE_PASSWORD=your-secure-password           # Пароль для входа в Flowise
MYSQL_ROOT_PASSWORD=your-mysql-root-password    # Root пароль для MySQL

# Traefik Dashboard доступен только с localhost:8082 для безопасности
# TRAEFIK_PASSWORD не требуется - доступ ограничен локальным хостом

# Часовой пояс (при необходимости)
TZ=Europe/Kiev
```

**🔐 Безопасность Traefik Dashboard:**
Traefik Dashboard доступен только с локального хоста (127.0.0.1) для максимальной безопасности. SSH туннель не требуется - прямой доступ заблокирован для внешних соединений.

### 🔐 Шаг 4: Проверка домена и запуск

```bash
# Проверка готовности домена и автоматический запуск
chmod +x ssl-check.sh
./ssl-check.sh
```

**Этот скрипт автоматически:**
- ✅ Устанавливает certbot (если нужно)
- ✅ Проверяет DNS домена и доступность
- ✅ Выполняет dry-run тест Let's Encrypt
- ✅ При успехе предлагает запустить все сервисы
- ✅ Запускает `docker compose up -d` с реальными SSL

### 🔍 Шаг 5: Проверка результата

```bash
# Проверить статус всех контейнеров
docker ps

# Проверить логи получения SSL
docker logs service_traefik

# Проверить статические файлы
ls -la /var/www/html/data/
```

**Ожидаемый результат:**
- Все контейнеры запущены (`Status: Up`)
- SSL сертификаты получены автоматически
- Сервисы доступны с валидными сертификатами

### 🌐 Шаг 6: Тестирование доступности сервисов

Откройте в браузере с **валидными SSL сертификатами**:

```bash
# Основные сервисы
https://your-domain.com              # Node-RED (логин: admin, пароль: NODE_RED_PASSWORD)
https://your-domain.com:5050         # Flowise AI (логин из FLOWISE_EMAIL/PASSWORD)
https://your-domain.com:7040         # LightRAG (JWT аутентификация, см. AUTH_ACCOUNTS в .env)
https://your-domain.com:8333/health  # Chroma-API Health Check (без аутентификации)
https://your-domain.com:8333/api     # Chroma-API (требует header: x-chroma-api-token)
https://your-domain.com/phpmyadmin   # phpMyAdmin (логин: root, пароль: MYSQL_ROOT_PASSWORD)
https://your-domain.com/data         # Статические файлы (без аутентификации)
```

#### 🔐 **Доступы к сервисам:**

| Сервис | URL | Логин | Пароль | Источник |
|--------|-----|-------|---------|----------|
| **Node-RED** | `https://your-domain.com` | `admin` | `NODE_RED_PASSWORD` | `.env` |
| **Flowise AI** | `https://your-domain.com:5050` | `FLOWISE_EMAIL` | `FLOWISE_PASSWORD` | `.env` |
| **LightRAG** | `https://your-domain.com:7040` | `AUTH_ACCOUNTS` | JWT токен | `.env` |
| **Chroma-API** | `https://your-domain.com:8333/api` | Header: `x-chroma-api-token` | `CHROMA_API_TOKEN` | `.env` |
| **phpMyAdmin** | `https://your-domain.com/phpmyadmin` | `root` | `MYSQL_ROOT_PASSWORD` | `.env` |
| **Traefik Dashboard** | `http://127.0.0.1:8082/dashboard/` | - | - | Localhost only |
| **Статика** | `https://your-domain.com/data` | - | - | Без аутентификации |

**Если сервисы недоступны:**
```bash
# Проверить статус контейнеров
docker ps -a

# Проверить логи конкретного сервиса
docker logs service_nodered
docker logs service_traefik

# Проверить сеть
docker network ls
```

### ✅ Готово! Система развернута

**Сервисы доступны с валидными SSL сертификатами:**
- ✅ `https://your-domain.com` (Node-RED)
- ✅ `https://your-domain.com:5050` (Flowise)
- ✅ `https://your-domain.com:7040` (LightRAG)
- ✅ `https://your-domain.com:8333/api` (Chroma-API)
- ✅ `https://your-domain.com/phpmyadmin` (База данных)
- ✅ `http://127.0.0.1:8082/dashboard/` (Traefik Dashboard - localhost only)
- ✅ Автоматическое обновление SSL сертификатов

---

## 🔐 Настройка SSL

### 📋 Автоматическое управление через ssl-check.sh

Проект включает **упрощенную** систему управления SSL:

```bash
# Основная команда - проверка домена и автозапуск
chmod +x ssl-check.sh
./ssl-check.sh

# Ручной запуск после успешной проверки
docker compose up -d

# Проверка логов SSL
docker logs service_traefik
```

### 🧪 Как работает ssl-check.sh:

1. **Проверка домена** - DNS резолвинг и доступность
2. **Dry-run тест** - certbot проверяет возможность получения SSL  
3. **Валидация** - убеждается что домен готов для Let's Encrypt
4. **Автозапуск** - предлагает запустить все сервисы
5. **Production SSL** - Traefik автоматически получает реальные сертификаты

### ✅ Преимущества новой схемы:

- 🚀 **Один шаг** вместо сложного алгоритма
- 🔍 **Предварительная проверка** домена без развертывания  
- ⚡ **Быстрое тестирование** (10-15 секунд)
- 🎯 **Только production** сертификаты (без staging режима)
- 🔒 **Автоматическое обновление** SSL

---

## 🛡️ Система безопасности

### 🔥 Расширенная защита Fail2ban

**Проект включает многоуровневую защиту от атак:**

#### 📋 Активные jail:
```bash
# Проверка статуса защиты
sudo fail2ban-client status

# Детали по каждому jail
sudo fail2ban-client status sshd           # SSH защита
sudo fail2ban-client status traefik-general # Общие веб-атаки
sudo fail2ban-client status nodered-auth   # Node-RED защита
sudo fail2ban-client status flowise-auth   # Flowise AI защита
```

#### 🎯 Уровни защиты:

**1. SSH защита (`sshd`):**
- Максимум 5 попыток за 10 минут
- Блокировка на 1 час
- Логи: `/var/log/auth.log`

**2. Общие веб-атаки (`traefik-general`):**
- Детекция 404 атак и сканирования
- Максимум 10 попыток за 5 минут
- Блокировка на 2 часа
- Защищает от: сканеров, ботов, автоматических атак

**3. Node-RED защита (`nodered-auth`):**
- Защита админ-панели на порту 443
- Максимум 3 попытки за 10 минут
- Блокировка на 4 часа
- Детекция брутфорса `/auth/token`

**4. Flowise AI защита (`flowise-auth`):**
- Защита AI-платформы на порту 5050
- Максимум 3 попытки за 10 минут
- Блокировка на 4 часа
- Защита API endpoints

### 🔄 Автосинхронизация логов

**Проблема:** Docker bind mount логов работает некорректно  
**Решение:** Автоматическая синхронизация каждые 2 минуты

#### 📜 Скрипт синхронизации:
```bash
# Ручной запуск синхронизации
/root/ai_project/sync-logs.sh

# Мониторинг процесса
tail -f /root/ai_project/logs/sync.log

# Проверка cron задач
crontab -l | grep sync-logs
```

#### ⚙️ Автоматический процесс:
1. **Каждые 2 минуты** копирует логи из контейнера Traefik
2. **Обновляет** `/root/ai_project/logs/access.log` на хосте
3. **Перезагружает** все jail fail2ban для актуализации данных
4. **Логирует** результат синхронизации

### 📊 Мониторинг безопасности

```bash
# Общий статус системы безопасности
sudo fail2ban-client status

# Просмотр заблокированных IP
sudo fail2ban-client status sshd | grep "Banned IP"

# Логи fail2ban в реальном времени
sudo tail -f /var/log/fail2ban.log

# Статистика атак за сегодня
grep "$(date +%Y-%m-%d)" /var/log/fail2ban.log | grep "Ban"

# Проверка синхронизации логов
tail -f /root/ai_project/logs/sync.log

# Размер актуальных логов Traefik
ls -lh /root/ai_project/logs/access.log
```

### 🚨 Типы детектируемых атак:

**SSH атаки:**
- Брутфорс попытки входа
- Сканирование SSH портов
- Автоматические боты

**Веб-атаки:**
- Сканирование директорий (404 атаки)
- Попытки доступа к админ-панелям
- Поиск PHP/ASP уязвимостей
- Попытки доступа к .env файлам

**Специализированные атаки:**
- Брутфорс Node-RED аутентификации
- Атаки на Flowise AI API
- Попытки обхода авторизации

### ⚡ Быстрые команды:

```bash
# Разбанить IP (при необходимости)
sudo fail2ban-client unban 192.168.1.100

# Перезагрузить все jail
sudo fail2ban-client reload

# Добавить IP в whitelist (постоянно)
# Добавьте в /etc/fail2ban/jail.local:
# ignoreip = 127.0.0.1/8 YOUR_IP

# Проверка конфигурации
sudo fail2ban-client -t
```

---

## 📊 Проверка и мониторинг

### 🛡️ Мониторинг системы безопасности

```bash
# Общий статус системы защиты
sudo fail2ban-client status

# Просмотр заблокированных IP по каждому jail
sudo fail2ban-client status sshd
sudo fail2ban-client status traefik-general
sudo fail2ban-client status nodered-auth
sudo fail2ban-client status flowise-auth

# Логи fail2ban в реальном времени
sudo tail -f /var/log/fail2ban.log

# Мониторинг синхронизации логов
tail -f /root/ai_project/logs/sync.log

# Статистика атак за сегодня
grep "$(date +%Y-%m-%d)" /var/log/fail2ban.log | grep "Ban" | wc -l

# Последние 10 заблокированных IP
grep "Ban" /var/log/fail2ban.log | tail -10

# Проверка работы cron синхронизации
crontab -l | grep sync-logs
ls -la /root/ai_project/logs/access.log
```

### 🔄 **Управление sync-logs.sh**

Скрипт `/root/ai_project/sync-logs.sh` решает проблему Docker bind mount для логов Traefik:

```bash
# Ручной запуск синхронизации
/root/ai_project/sync-logs.sh

# Проверка статуса синхронизации
tail -5 /root/ai_project/logs/sync.log

# Проверка размера синхронизированных логов
ls -lh /root/ai_project/logs/access.log

# Проверка активности cron задачи
grep sync-logs /var/log/syslog | tail -5
```

**Как работает синхронизация:**
1. Каждые 2 минуты cron запускает `sync-logs.sh`
2. Скрипт копирует логи из контейнера `service_traefik:/var/log/access.log`
3. Логи сохраняются в `/root/ai_project/logs/access.log` на хосте
4. Автоматически перезагружаются все fail2ban jail
5. Логируется результат в `/root/ai_project/logs/sync.log`

### 🔍 Проверка работоспособности сервисов

```bash
# Статус всех контейнеров
docker ps

# Ресурсы системы
docker stats

# Использование дискового пространства
docker system df

# Проверка сетей
docker network ls
```

### 📋 Проверка конкретных сервисов

```bash
# Node-RED логи
docker logs service_nodered -f

# Flowise логи  
docker logs service_flowise -f

# MySQL логи
docker logs service_mysql -f

# Traefik логи (SSL, маршрутизация)
docker logs service_traefik -f

# Nginx статические файлы
docker logs service_nginx_static -f
```

### 🌐 Проверка доступности через браузер

| Сервис | URL | Логин | Пароль | Назначение |
|--------|-----|-------|---------|-----------|
| Node-RED | `https://your-domain.com` | `admin` | `NODE_RED_PASSWORD` | Визуальное программирование |
| Flowise | `https://your-domain.com:5050` | `FLOWISE_EMAIL` | `FLOWISE_PASSWORD` | AI workflow platform |
| LightRAG | `https://your-domain.com:7040` | `AUTH_ACCOUNTS` | JWT токен | Knowledge Graph & RAG |
| Chroma-API | `https://your-domain.com:8333/api` | Header: `x-chroma-api-token` | `CHROMA_API_TOKEN` | REST API для ChromaDB |
| phpMyAdmin | `https://your-domain.com/phpmyadmin` | `root` | `MYSQL_ROOT_PASSWORD` | Управление MySQL |
| Статические файлы | `https://your-domain.com/data/` | - | - | Файловый сервер |
| Traefik Dashboard | `http://127.0.0.1:8082/dashboard/` | - | - | Мониторинг прокси (localhost only) |

### 📝 Полная диагностика системы

```bash
# Комплексная проверка системы
echo "=== SECURITY STATUS ===" && \
sudo fail2ban-client status && \
echo "=== DOCKER STATUS ===" && \
docker ps && \
echo "=== FIREWALL STATUS ===" && \
sudo ufw status numbered && \
echo "=== SYNC STATUS ===" && \
tail -3 /root/ai_project/logs/sync.log && \
echo "=== CRON STATUS ===" && \
crontab -l | grep sync-logs

# Проверка всех логов системы
echo "=== FAIL2BAN ACTIVITY TODAY ===" && \
grep "$(date +%Y-%m-%d)" /var/log/fail2ban.log | grep "Ban" | wc -l && \
echo "=== ACCESS LOG SIZE ===" && \
ls -lh /root/ai_project/logs/access.log 2>/dev/null || echo "Access log not synced yet" && \
echo "=== RECENT BANS ===" && \
grep "Ban" /var/log/fail2ban.log | tail -5
```

### 📊 Мониторинг ресурсов системы

```bash
# Использование ресурсов Docker
docker stats --no-stream

# Дисковое пространство Docker
docker system df

# Общее использование диска
df -h

# Проверка открытых портов
ss -tulpn | grep -E ':(22|80|443|5050|3306|6379|8000|8082)'

# Мониторинг системных служб
sudo systemctl status docker fail2ban ufw
```

### 📊 Мониторинг сетевой активности

```bash
# Мониторинг входящих соединений на 443 порту
sudo ss -tulpn | grep :443

# Мониторинг Flowise на 5050 порту
sudo ss -tulpn | grep :5050

# Проверка соединений с базами данных
sudo ss -tulpn | grep -E ':(3306|6379|8000)'

# 10 самых активных IP адресов в логах
if [ -f /root/ai_project/logs/access.log ]; then
    awk '{print $1}' /root/ai_project/logs/access.log | sort | uniq -c | sort -nr | head -10
else
    echo "Access logs not synced yet. Run: /root/ai_project/sync-logs.sh"
fi

# Последние 50 запросов к Node-RED
if [ -f /root/ai_project/logs/access.log ]; then
    grep "nodered" /root/ai_project/logs/access.log | tail -50
fi

# Последние 50 запросов к Flowise
if [ -f /root/ai_project/logs/access.log ]; then
    grep ":5050" /root/ai_project/logs/access.log | tail -50
fi
```

### 📈 Мониторинг SSL сертификатов

```bash
# Проверка сертификатов через openssl
openssl s_client -connect domain.com:443 -servername domain.com 2>/dev/null | openssl x509 -noout -dates

# Проверка через curl
curl -I https://domain.com

# Информация о сертификатах Traefik
ls -la /root/ai_project/letsencrypt/acme.json
```

### 🗄️ Проверка баз данных

```bash
# Подключение к MySQL
docker exec -it service_mysql mysql -u root -p

# Проверка Redis
docker exec -it service_redis redis-cli ping

# Проверка ChromaDB
curl http://localhost:8333/api/v2/heartbeat
```

---

## ⚙️ Управление сервисами

### 🚀 Основные команды Docker Compose

```bash
# Запуск всех сервисов
docker compose up -d

# Остановка всех сервисов
docker compose down

# Перезапуск конкретного сервиса
docker compose restart service_name

# Пересборка и запуск
docker compose up -d --build

# Просмотр логов
docker compose logs -f service_name
```

### 🔄 Пересборка контейнеров без потери данных

```bash
# Обновить все образы до последних версий
docker compose pull

# Пересоздать все контейнеры с новыми образами (данные сохраняются в volumes)
docker compose up -d --force-recreate

# Одной командой (рекомендуется)
docker compose pull && docker compose up -d --force-recreate

# Проверить статус после пересборки
docker compose ps
docker volume ls | grep ai_project
```

**Важно:** Docker volumes с данными НЕ удаляются при пересборке:
- `mysql_data` - данные MySQL
- `nodered_data` - конфигурация Node-RED
- `flowise_data` - данные Flowise
- `lightrag_storage` - данные LightRAG (граф знаний, RAG)
- `redis_data` - кэш Redis
- `chroma_data` - векторная база данных

**Опасные команды (потеря данных):**
```bash
# ❌ НЕ ВЫПОЛНЯЙТЕ БЕЗ BACKUP!
docker compose down -v          # Удалит все volumes с данными
docker system prune -a --volumes # Удалит ВСЕ данные Docker
```

### 🔄 Управление отдельными контейнерами

```bash
# Перезапуск конкретного контейнера
docker restart service_nodered

# Вход в контейнер
docker exec -it service_nodered /bin/bash

# Копирование файлов из/в контейнер
docker cp file.txt service_nodered:/data/
docker cp service_nodered:/data/file.txt ./
```

### 🔐 Смена пароля Node-RED

**Node-RED имеет автоматическую систему управления паролями:**

#### 📝 **Простой способ (рекомендуется):**

1. **Измените пароль в `.env` файле:**
```bash
nano .env
# Найдите строку: NODE_RED_PASSWORD=старый_пароль
# Замените на:   NODE_RED_PASSWORD=новый_пароль
```

2. **Перезапустите с очисткой данных:**
```bash
# ⚠️ ВАЖНО: Используйте именно эту последовательность команд!
cd /root/ai_project

# Остановить Node-RED
docker compose stop nodered

# Очистить зашифрованные данные (иначе пароль не изменится)
docker run --rm -v ai_project_nodered_data:/data alpine sh -c "
rm -f /data/flows_cred.json
rm -f /data/.flows*.backup"

# Запустить с новыми настройками
docker compose up -d nodered

# При необходимости перезапустить Traefik
docker compose restart traefik
```

#### ⚡ **Одной командой:**
```bash
# После изменения .env выполните:
docker compose stop nodered && \
docker run --rm -v ai_project_nodered_data:/data alpine rm -f /data/flows_cred.json /data/.flows*.backup && \
docker compose up -d nodered && \
sleep 10 && docker compose restart traefik
```

#### ❌ **Почему простой `restart` не работает:**
- Node-RED кэширует зашифрованные данные
- При смене пароля старые credentials нельзя расшифровать
- **Обязательно** нужно удалить `flows_cred.json` перед запуском

#### ✅ **Проверка смены пароля:**
```bash
# Тест API с новым паролем (должен вернуть access_token):
curl -X POST -H "Content-Type: application/json" \
  -d '{"client_id":"node-red-admin","grant_type":"password","username":"admin","password":"НОВЫЙ_ПАРОЛЬ","scope":"*"}' \
  https://your-domain.com/auth/token

# Тест со старым паролем (должен вернуть ошибку):
curl -X POST -H "Content-Type: application/json" \
  -d '{"client_id":"node-red-admin","grant_type":"password","username":"admin","password":"СТАРЫЙ_ПАРОЛЬ","scope":"*"}' \
  https://your-domain.com/auth/token
```

#### 🎯 **Как работает автоматическая система:**
1. **Init-контейнер** (`nodered-init`) читает `NODE_RED_PASSWORD` из `.env`
2. **Генерирует bcrypt хеш** для нового пароля
3. **Создает `settings.js`** с правильным хешем аутентификации
4. **Node-RED запускается** с новыми настройками
5. **Старые пароли перестают работать** автоматически

**🔒 Преимущества данного подхода:**
- ✅ Никаких захардкоженных паролей в коде
- ✅ Все пароли берутся из переменных окружения
- ✅ Автоматическая генерация bcrypt хешей
- ✅ Безопасное хранение в Docker volume
- ✅ Простая смена на новом сервере

### 💾 Управление данными и volumes

```bash
# Список volumes
docker volume ls

# Информация о конкретном volume
docker volume inspect ai_project_mysql_data

# Backup MySQL данных
docker exec service_mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > backup.sql

# Restore MySQL данных
docker exec -i service_mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} < backup.sql
```

### 🧹 Очистка системы

```bash
# Удаление неиспользуемых контейнеров, сетей, образов
docker system prune -a

# Удаление неиспользуемых volumes (ОСТОРОЖНО!)
docker volume prune

# Полная очистка Docker (ОСТОРОЖНО!)
docker system prune -a --volumes
```

---

## 🚨 Устранение проблем

### 🔧 Частые проблемы и решения

#### 🚫 Сервисы недоступны через браузер

```bash
# 1. Проверить статус контейнеров
docker ps -a

# 2. Проверить логи Traefik
./ssl-manager.sh logs

# 3. Проверить DNS настройки
nslookup your-domain.com
dig your-domain.com

# 4. Проверить firewall
sudo ufw status

# 5. Проверить открытые порты
netstat -tulpn | grep -E ':(80|443|5050)'
```

#### 🔒 SSL сертификаты не получаются

```bash
# 1. Убедиться что домен указывает на сервер
nslookup your-domain.com

# 2. Запустить проверку домена
chmod +x ssl-check.sh
./ssl-check.sh

# 3. Если проверка прошла, но сертификаты не получены
docker logs service_traefik | grep -i acme

# 4. Перезапустить Traefik
docker restart service_traefik

# 5. Убедиться что порт 80 доступен для challenge
curl -v http://your-domain.com/.well-known/acme-challenge/test
```

#### 💾 Проблемы с базой данных

```bash
# 1. Проверить статус MySQL контейнера
docker logs service_mysql

# 2. Проверить подключение
docker exec service_mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"

# 3. Пересоздать базу данных (ОСТОРОЖНО!)
docker compose down
docker volume rm ai_project_mysql_data
docker compose up -d mysql_db
```

#### 🔗 Сервисы не могут подключиться друг к другу

```bash
# 1. Проверить Docker сеть
docker network inspect ai_project_internal

# 2. Проверить имена контейнеров в сети
docker network ls
docker network inspect bridge

# 3. Тест подключения между контейнерами
docker exec service_nodered ping service_mysql
docker exec service_flowise ping service_redis
```

### 📝 Диагностические команды

```bash
# Полная диагностика системы
echo "=== DOCKER STATUS ===" && docker --version
echo "=== CONTAINERS ===" && docker ps -a
echo "=== IMAGES ===" && docker images
echo "=== VOLUMES ===" && docker volume ls
echo "=== NETWORKS ===" && docker network ls
echo "=== DISK USAGE ===" && docker system df
echo "=== SSL FILES ===" && ls -la /root/ai_project/letsencrypt/
echo "=== FIREWALL ===" && sudo ufw status
echo "=== PORTS ===" && netstat -tulpn | grep -E ':(22|80|443|5050|3306|6379)'
```

### 📞 Получение помощи

```bash
# Проверить версии
docker --version
docker compose --version

# Экспорт конфигурации для анализа (без паролей!)
docker compose config > docker compose-parsed.yml

# Сохранить логи всех сервисов
docker compose logs > all-services.log 2>&1
```

### 🔄 Полный перезапуск проекта

```bash
# ВНИМАНИЕ: Это остановит все сервисы!

# 1. Остановить все контейнеры
docker compose down

# 2. Убедиться что всё остановлено
docker ps -a

# 3. Запустить заново
docker compose up -d

# 4. Проверить статус
docker ps
```

---

## 🎯 Заключение

После выполнения всех шагов у вас будет работающая система с:

✅ **Автоматическими SSL сертификатами** (Let's Encrypt)
✅ **Node-RED** для автоматизации и Telegram ботов + публичные файлы
✅ **Flowise AI** для создания AI workflow
✅ **LightRAG** для Knowledge Graph и RAG (Retrieval Augmented Generation)
✅ **Chroma-API** - REST API для ChromaDB с токен-аутентификацией
✅ **MySQL + phpMyAdmin** для управления базами данных
✅ **Redis** для кэширования
✅ **ChromaDB** для векторных операций (доступ через Chroma-API)
✅ **Nginx** для статических файлов
✅ **Общая папка** Node-RED → Nginx для публичных файлов (`/data/public/`)
✅ **Автоматизированной проверкой SSL** через `ssl-check.sh`
✅ **Безопасностью** (UFW + Fail2ban + Rate Limiting)
✅ **Автоматической системой аутентификации** - все пароли из `.env`

### 🔐 **Система аутентификации:**

**Node-RED защищен автоматической системой паролей:**
- 🔑 **Логин:** `admin` 
- 🔑 **Пароль:** значение из `NODE_RED_PASSWORD` в файле `.env`
- 🔄 **Смена пароля:** Простое изменение в `.env` + перезапуск
- 🛡️ **Безопасность:** Bcrypt хеши, никаких захардкоженных паролей
- ⚡ **Автоматизация:** Init-контейнер генерирует настройки при каждом запуске

**🎉 Система готова к использованию с полной защитой паролем!**

### 📁 **Работа с файлами в Node-RED:**

**Для сохранения публичных файлов используй путь:** `/data/public/filename.txt`

**Файлы будут доступны по URL:** `https://your-domain.com/data/filename.txt`

**Права доступа:** папка `/var/www/html/data/` имеет права `777` для записи из Node-RED