# LightRAG Workspaces - Архитектура и Управление

> ⚠️ **ВАЖНО:** Перед использованием этой конфигурации в production:
> - Замените креды на собственные безопасные пароли и ключи
> - Используйте генератор паролей: `openssl rand -base64 32`
> - Замените `primelevel.group` на ваш домен
> - Никогда не коммитьте реальные секреты в Git!

## 📖 Механизм работы Workspaces

### Что такое Workspace в LightRAG?

**Workspace** - это механизм **логической изоляции данных** внутри LightRAG, который позволяет:

- Хранить данные нескольких проектов в одной физической базе данных
- Изолировать данные на уровне запросов (через WHERE фильтры)
- Экономить ресурсы за счёт общей инфраструктуры
- Масштабировать систему горизонтально

### Как это работает технически?

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Volume (lightrag_storage)          │
│                                                               │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │  Workspace A  │  │  Workspace B  │  │  Workspace C  │   │
│  │               │  │               │  │               │   │
│  │  • Граф       │  │  • Граф       │  │  • Граф       │   │
│  │  • Векторы    │  │  • Векторы    │  │  • Векторы    │   │
│  │  • Документы  │  │  • Документы  │  │  • Документы  │   │
│  └───────────────┘  └───────────────┘  └───────────────┘   │
│                                                               │
│  Данные логически изолированы через поле "workspace"         │
└─────────────────────────────────────────────────────────────┘
         ▲                  ▲                  ▲
         │                  │                  │
    ┌─────────┐       ┌─────────┐       ┌─────────┐
    │ Port    │       │ Port    │       │ Port    │
    │ 7040    │       │ 7041    │       │ 7042    │
    └─────────┘       └─────────┘       └─────────┘
```

**Ключевые моменты:**

1. **Общее хранилище** - один Docker volume для всех workspaces
2. **Логическая изоляция** - данные разделяются через параметр `workspace`
3. **Физическая структура** - каждый workspace создаёт свою подпапку в volume
4. **Индексы БД** - автоматически фильтруют по workspace:
   ```sql
   CREATE INDEX idx_workspace_status ON documents (workspace, status);
   ```

5. **API изоляция** - разные порты/контейнеры для параллельной обработки

---

## 🏗️ Архитектура для нескольких Workspaces

### Текущая конфигурация (один workspace по умолчанию)

**Проблема:** Один контейнер `lightrag` обрабатывает все запросы последовательно.

**Файлы для изменения:**
1. [`traefik/traefik.yml`](traefik/traefik.yml) - добавить entrypoints для новых портов
2. [`docker-compose.yml`](docker-compose.yml) - добавить сервисы для каждого workspace
3. [`.env`](.env) - опционально, если нужны workspace-специфичные настройки

---

### Шаг 1: Настройка для Project A (первый workspace)

#### 1.1. Добавить entrypoint в Traefik

Откройте [`traefik/traefik.yml`](traefik/traefik.yml) и добавьте после строки 36:

```yaml
  # Кастомный HTTPS entry point для LightRAG Project A
  websecure-7041:
    address: ":7041"
```

Также обновите секцию `ports` в сервисе `traefik` в [`docker-compose.yml`](docker-compose.yml):

```yaml
services:
  traefik:
    # ... existing config ...
    ports:
      - "80:80"
      - "127.0.0.1:8082:8080"
      - "443:443"
      - "5050:5050"
      - "7040:7040"     # Existing LightRAG (default workspace)
      - "7041:7041"     # NEW: LightRAG Project A
      - "8333:8333"
```

#### 1.2. Добавить сервис в docker-compose.yml

Добавьте **после** существующего сервиса `lightrag` (примерно после строки 228):

```yaml
  # ===========================================
  # LIGHTRAG PROJECT A
  # ===========================================
  lightrag_project_a:
    image: ghcr.io/hkuds/lightrag:latest
    container_name: service_lightrag_project_a
    hostname: lightrag-project-a
    restart: unless-stopped
    environment:
      - TZ=${TZ}
      - TIKTOKEN_CACHE_DIR=/app/data/tiktoken
      - PORT=9621
    volumes:
      # ВАЖНО: Используем тот же volume для персистентности
      - lightrag_storage:/app/data/rag_storage
      - ./lightrag/data/inputs:/app/data/inputs
      - ./lightrag/data/tiktoken:/app/data/tiktoken
      - ./lightrag/config.ini:/app/config.ini
      - ./.env:/app/.env:ro
      - ./shared:/data/shared
      - ./lightrag/patches/document_routes.py:/app/lightrag/api/routers/document_routes.py:ro
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - internal
    # КЛЮЧЕВОЙ МОМЕНТ: передаём workspace через command (только аргументы, ENTRYPOINT уже содержит python -m lightrag.api.lightrag_server)
    command: ["--workspace", "project_a", "--port", "9621"]
    labels:
      - "traefik.enable=true"
      # HTTP роутер с редиректом на HTTPS
      - "traefik.http.routers.lightrag-a-http.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.lightrag-a-http.entrypoints=web"
      - "traefik.http.routers.lightrag-a-http.middlewares=lightrag-a-https-redirect"
      # HTTPS роутер для LightRAG Project A на порту 7041
      - "traefik.http.routers.lightrag-a-https.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.lightrag-a-https.entrypoints=websecure-7041"
      - "traefik.http.routers.lightrag-a-https.priority=91"
      - "traefik.http.routers.lightrag-a-https.tls=true"
      - "traefik.http.routers.lightrag-a-https.tls.certresolver=letsencrypt"
      # Сервис LightRAG Project A
      - "traefik.http.services.lightrag-a.loadbalancer.server.port=9621"
      # Middleware для редиректа на HTTPS
      - "traefik.http.middlewares.lightrag-a-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.middlewares.lightrag-a-https-redirect.redirectscheme.port=7041"
```

#### 1.3. Применить изменения

```bash
cd /root/ai_project

# Пересоздать только Traefik для применения новых entrypoints
docker compose up -d --force-recreate traefik

# Запустить новый сервис Project A
docker compose up -d lightrag_project_a

# Проверить статус
docker compose ps | grep lightrag
```

#### 1.4. Проверка работы

```bash
# Проверка здоровья Project A
curl -k https://primelevel.group:7041/health

# Добавление документа в Project A
curl -X POST "https://primelevel.group:7041/documents/text" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: xxxxxxxxxxxxxx" \
  -d '{
    "text": "Test document for Project A"
  }' -k

# Проверка, что данные изолированы (должен вернуть 0 документов для default workspace)
curl -X GET "https://primelevel.group:7040/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k
```

---

## 🔄 Пошаговый алгоритм добавления Project B (второго workspace)

### Шаг 1: Обновить Traefik конфигурацию

**Файл:** [`traefik/traefik.yml`](traefik/traefik.yml)

Добавьте после `websecure-7041`:

```yaml
  # Кастомный HTTPS entry point для LightRAG Project B
  websecure-7042:
    address: ":7042"
```

### Шаг 2: Обновить docker-compose.yml

**Файл:** [`docker-compose.yml`](docker-compose.yml)

#### 2.1. Добавить порт в Traefik

В секции `traefik.ports` добавьте:

```yaml
      - "7042:7042"     # NEW: LightRAG Project B
```

#### 2.2. Добавить новый сервис

Скопируйте конфигурацию `lightrag_project_a` и измените:

```yaml
  # ===========================================
  # LIGHTRAG PROJECT B
  # ===========================================
  lightrag_project_b:
    image: ghcr.io/hkuds/lightrag:latest
    container_name: service_lightrag_project_b
    hostname: lightrag-project-b
    restart: unless-stopped
    environment:
      - TZ=${TZ}
      - TIKTOKEN_CACHE_DIR=/app/data/tiktoken
      - PORT=9621
    volumes:
      # ВАЖНО: Тот же volume для общего хранилища
      - lightrag_storage:/app/data/rag_storage
      - ./lightrag/data/inputs:/app/data/inputs
      - ./lightrag/data/tiktoken:/app/data/tiktoken
      - ./lightrag/config.ini:/app/config.ini
      - ./.env:/app/.env:ro
      - ./shared:/data/shared
      - ./lightrag/patches/document_routes.py:/app/lightrag/api/routers/document_routes.py:ro
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - internal
    # ИЗМЕНЕНО: workspace = "project_b" (только аргументы, ENTRYPOINT уже содержит python -m lightrag.api.lightrag_server)
    command: ["--workspace", "project_b", "--port", "9621"]
    labels:
      - "traefik.enable=true"
      # HTTP роутер с редиректом на HTTPS
      - "traefik.http.routers.lightrag-b-http.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.lightrag-b-http.entrypoints=web"
      - "traefik.http.routers.lightrag-b-http.middlewares=lightrag-b-https-redirect"
      # HTTPS роутер для LightRAG Project B на порту 7042
      - "traefik.http.routers.lightrag-b-https.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.lightrag-b-https.entrypoints=websecure-7042"
      - "traefik.http.routers.lightrag-b-https.priority=92"
      - "traefik.http.routers.lightrag-b-https.tls=true"
      - "traefik.http.routers.lightrag-b-https.tls.certresolver=letsencrypt"
      # Сервис LightRAG Project B
      - "traefik.http.services.lightrag-b.loadbalancer.server.port=9621"
      # Middleware для редиректа на HTTPS
      - "traefik.http.middlewares.lightrag-b-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.middlewares.lightrag-b-https-redirect.redirectscheme.port=7042"
```

### Шаг 3: Применить изменения

```bash
cd /root/ai_project

# 1. Пересоздать Traefik для применения нового entrypoint
docker compose up -d --force-recreate traefik

# 2. Запустить Project B
docker compose up -d lightrag_project_b

# 3. Проверить, что все контейнеры работают
docker compose ps
```

**Важно про синтаксис `command`:**

Docker-образ LightRAG имеет встроенный `ENTRYPOINT`:
```dockerfile
ENTRYPOINT ["python", "-m", "lightrag.api.lightrag_server"]
```

Поэтому в `command` нужно передавать **только аргументы**, а не полную команду:
- ✅ **Правильно:** `command: ["--workspace", "project_a", "--port", "9621"]`
- ❌ **Неправильно:** `command: ["lightrag-server", "--workspace", "project_a"]`
- ❌ **Неправильно:** `command: ["python", "-m", "lightrag.api.lightrag_server", "--workspace", "project_a"]`

Проверить ENTRYPOINT можно командой:
```bash
docker inspect service_lightrag | grep -A 5 "Entrypoint"
```

**Ожидаемый результат:**

```
NAME                         STATUS
service_lightrag             Up (default workspace, port 7040)
service_lightrag_project_a   Up (project_a, port 7041)
service_lightrag_project_b   Up (project_b, port 7042)
service_traefik              Up
```

### Шаг 4: Проверка изоляции данных

```bash
# Добавить документ в Project B
curl -X POST "https://primelevel.group:7042/documents/text" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: xxxxxxxxxxxxxx" \
  -d '{
    "text": "Document only for Project B"
  }' -k

# Проверить, что Project A не видит документы Project B
curl -X GET "https://primelevel.group:7041/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.total'
# Должно вернуть количество документов только из Project A

# Проверить, что Project B видит только свои документы
curl -X GET "https://primelevel.group:7042/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.total'
# Должно вернуть только документы Project B
```

---

## 💾 Персистентность данных при перезагрузке

### Как сохраняются данные?

**Docker Volume:** `lightrag_storage` (Docker-managed volume)

```bash
# Посмотреть информацию о volume
docker volume inspect ai_project_lightrag_storage

# Вывод:
[
    {
        "Name": "ai_project_lightrag_storage",
        "Driver": "local",
        "Mountpoint": "/var/lib/docker/volumes/ai_project_lightrag_storage/_data",
        ...
    }
]
```

**Структура данных внутри volume:**

```
/var/lib/docker/volumes/ai_project_lightrag_storage/_data/
├── default/                    # Default workspace (port 7040)
│   ├── graph_chunk_entity_relation.graphml
│   ├── kv_store_*.json
│   ├── vdb_chunks.json
│   └── doc_status.json
├── project_a/                  # Project A workspace (port 7041)
│   ├── graph_chunk_entity_relation.graphml
│   ├── kv_store_*.json
│   ├── vdb_chunks.json
│   └── doc_status.json
└── project_b/                  # Project B workspace (port 7042)
    ├── graph_chunk_entity_relation.graphml
    ├── kv_store_*.json
    ├── vdb_chunks.json
    └── doc_status.json
```

### Гарантии сохранности данных

✅ **Данные сохраняются при:**
- Перезапуске контейнеров (`docker compose restart`)
- Пересоздании контейнеров (`docker compose up -d --force-recreate`)
- Перезагрузке сервера
- Обновлении образа LightRAG

❌ **Данные НЕ сохранятся при:**
- Удалении volume (`docker volume rm ai_project_lightrag_storage`)
- Выполнении `docker compose down -v` (флаг `-v` удаляет volumes)

### Проверка персистентности

```bash
# 1. Добавить документ в Project A
curl -X POST "https://primelevel.group:7041/documents/text" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: xxxxxxxxxxxxxx" \
  -d '{"text": "Persistence test"}' -k

# 2. Запомнить количество документов
curl -X GET "https://primelevel.group:7041/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.total'

# 3. Перезапустить контейнер
docker compose restart lightrag_project_a

# 4. Проверить, что данные на месте
curl -X GET "https://primelevel.group:7041/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.total'
# Должно вернуть то же количество
```

---

## 🔧 Управление Workspaces

### Просмотр всех workspaces

```bash
# Войти в контейнер
docker exec -it service_lightrag bash

# Посмотреть структуру данных
ls -la /app/data/rag_storage/

# Вывод:
drwxr-xr-x 2 root root 4096 Oct 16 12:00 default
drwxr-xr-x 2 root root 4096 Oct 16 12:05 project_a
drwxr-xr-x 2 root root 4096 Oct 16 12:10 project_b
```

### Резервное копирование workspace

```bash
# Бэкап всех данных
docker run --rm \
  -v ai_project_lightrag_storage:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/lightrag_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# Бэкап конкретного workspace
docker run --rm \
  -v ai_project_lightrag_storage:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/project_a_$(date +%Y%m%d_%H%M%S).tar.gz -C /data/project_a .
```

### Восстановление из бэкапа

```bash
# Восстановить всё
docker run --rm \
  -v ai_project_lightrag_storage:/data \
  -v $(pwd)/backups:/backup \
  alpine sh -c "cd /data && tar xzf /backup/lightrag_backup_YYYYMMDD_HHMMSS.tar.gz"

# Восстановить конкретный workspace
docker run --rm \
  -v ai_project_lightrag_storage:/data \
  -v $(pwd)/backups:/backup \
  alpine sh -c "mkdir -p /data/project_a && cd /data/project_a && tar xzf /backup/project_a_YYYYMMDD_HHMMSS.tar.gz"
```

### Удаление workspace

```bash
# ВНИМАНИЕ: Удаляет все данные workspace без возможности восстановления!

# 1. Остановить контейнер workspace
docker compose stop lightrag_project_b

# 2. Удалить данные
docker exec service_lightrag rm -rf /app/data/rag_storage/project_b

# 3. Удалить сервис из docker-compose.yml
# 4. Пересоздать стек
docker compose up -d
```

---

## 📊 Мониторинг и отладка

### Проверка здоровья всех workspaces

```bash
# Скрипт для проверки всех workspaces
for port in 7040 7041 7042; do
  echo "=== Checking port $port ==="
  curl -s -k https://primelevel.group:$port/health | jq
done
```

### Просмотр логов

```bash
# Логи конкретного workspace
docker compose logs -f lightrag_project_a

# Логи всех LightRAG контейнеров
docker compose logs -f lightrag lightrag_project_a lightrag_project_b

# Последние 100 строк
docker compose logs --tail=100 lightrag_project_a
```

### Мониторинг использования ресурсов

```bash
# Статистика по всем контейнерам LightRAG
docker stats $(docker ps --filter "name=lightrag" --format "{{.Names}}")
```

---

## 🚀 Рекомендации по масштабированию

### Когда добавлять новый workspace?

✅ **Добавляйте отдельный workspace если:**
- Нужна полная изоляция данных между проектами
- Требуется параллельная обработка запросов
- Разные проекты имеют разную нагрузку
- Нужен независимый мониторинг производительности

❌ **Не нужен отдельный workspace если:**
- Проекты связаны и должны делиться знаниями
- Низкая нагрузка (можно использовать один контейнер с параметром `workspace` в API)
- Ограниченные ресурсы сервера

### Оптимизация производительности

**Настройки в `.env` для высоконагруженных workspaces:**

```env
# Увеличьте параллелизм для workspace с большим объемом данных
MAX_ASYNC=16                    # Увеличено с 12
MAX_PARALLEL_INSERT=5           # Увеличено с 3
EMBEDDING_FUNC_MAX_ASYNC=32     # Увеличено с 24
EMBEDDING_BATCH_NUM=200         # Увеличено со 100
```

**Ограничение ресурсов в docker-compose.yml:**

```yaml
  lightrag_project_a:
    # ... existing config ...
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

---

## 📝 Чек-лист при добавлении нового Workspace

- [ ] Добавить entrypoint в [`traefik/traefik.yml`](traefik/traefik.yml)
- [ ] Добавить порт в секцию `traefik.ports` в [`docker-compose.yml`](docker-compose.yml)
- [ ] Создать новый сервис в [`docker-compose.yml`](docker-compose.yml) с уникальным:
  - [ ] `container_name`
  - [ ] `hostname`
  - [ ] `--workspace` параметром в `command`
  - [ ] `entrypoints` (websecure-XXXX)
  - [ ] `priority` в Traefik labels
- [ ] Пересоздать Traefik: `docker compose up -d --force-recreate traefik`
- [ ] Запустить новый workspace: `docker compose up -d lightrag_project_X`
- [ ] Проверить health: `curl -k https://primelevel.group:XXXX/health`
- [ ] Проверить изоляцию данных
- [ ] Добавить workspace в мониторинг
- [ ] Создать резервную копию данных

---

## 🔒 Безопасность

### Изоляция данных

- ✅ **Логическая изоляция:** Гарантируется на уровне LightRAG через фильтры по workspace
- ✅ **API изоляция:** Каждый workspace на отдельном порту с собственным SSL
- ✅ **Аутентификация:** Все workspaces используют общий `LIGHTRAG_API_KEY` из `.env`

### Рекомендации:

1. **Разные API ключи для разных workspaces:**
   - Создайте отдельные `.env` файлы: `.env.project_a`, `.env.project_b`
   - Монтируйте их в `env_file` секции соответствующих сервисов

2. **Firewall правила:**
   ```bash
   # Ограничить доступ к workspace только с определённых IP
   ufw allow from 192.168.1.0/24 to any port 7041
   ```

3. **Rate limiting через Traefik:**
   ```yaml
   labels:
     - "traefik.http.middlewares.lightrag-a-ratelimit.ratelimit.average=100"
     - "traefik.http.middlewares.lightrag-a-ratelimit.ratelimit.burst=50"
     - "traefik.http.routers.lightrag-a-https.middlewares=lightrag-a-ratelimit"
   ```

---

## 📞 Полезные команды

```bash
# Быстрый перезапуск всех LightRAG workspaces
docker compose restart $(docker compose ps --services | grep lightrag)

# Просмотр размера данных каждого workspace
docker exec service_lightrag du -sh /app/data/rag_storage/*

# Экспорт конфигурации для документации
docker compose config > docker-compose.resolved.yml

# Проверка SSL сертификатов
echo | openssl s_client -connect primelevel.group:7041 -servername primelevel.group 2>/dev/null | openssl x509 -noout -dates
```

---

## ❓ Часто задаваемые вопросы (FAQ)

### 1. ✅ Default workspace (порт 7040) продолжит работать без изменений?

**Да, гарантируется полная совместимость:**

- Контейнер `service_lightrag` остаётся без изменений
- Все данные в `/app/data/rag_storage/default/` сохранятся
- Никаких миграций не требуется
- Изоляция данных 100% - новые workspaces не затронут default

**Проверка после добавления project_a:**
```bash
# Проверить, что старые данные на месте
curl -X GET "https://primelevel.group:7040/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.total'
# Должно вернуть прежнее количество документов
```

**Структура данных в volume после добавления workspaces:**
```
/var/lib/docker/volumes/ai_project_lightrag_storage/_data/
├── default/      # ← Существующие данные (порт 7040) - БЕЗ ИЗМЕНЕНИЙ
├── project_a/    # ← Новый workspace (порт 7041)
└── project_b/    # ← Новый workspace (порт 7042)
```

---

### 2. ✅ Да, через UI можно заходить в каждый workspace отдельно

**URLs для WebUI:**

| Workspace | Port | URL | Описание |
|-----------|------|-----|----------|
| Default | 7040 | `https://primelevel.group:7040` | Оригинальный workspace |
| Project A | 7041 | `https://primelevel.group:7041` | Изолированный workspace для проекта A |
| Project B | 7042 | `https://primelevel.group:7042` | Изолированный workspace для проекта B |

**Каждый workspace имеет:**
- ✅ Свой Web UI
- ✅ Свой API endpoint
- ✅ Свою базу знаний
- ✅ Свой граф (изолированный)
- ✅ Независимую обработку запросов

**Визуальная схема доступа:**

```
Browser → https://primelevel.group:7040 → service_lightrag          → /default/
Browser → https://primelevel.group:7041 → service_lightrag_project_a → /project_a/
Browser → https://primelevel.group:7042 → service_lightrag_project_b → /project_b/
```

---

### 3. 🔐 Логин и пароль для UI всех workspaces

**Текущая конфигурация:** Все workspaces используют **общую аутентификацию** из [.env](.env:75-85):

```env
# JWT Authentication
AUTH_ACCOUNTS=admin:xxxxxxxxxxxxxx
TOKEN_SECRET=xxxxxxxxxxxxxx

# API Key Authentication
LIGHTRAG_API_KEY=xxxxxxxxxxxxxx
```

**Важно:** Логин и пароль одинаковый для всех workspaces (default, project_a, project_b). Если нужны разные логины и пароли для каждого workspace, требуется создать три отдельных `.env` файла.

#### Вход через Web UI:

**Для всех workspaces (7040, 7041, 7042):**

| Поле | Значение |
|------|----------|
| **Username** | `admin` |
| **Password** | `xxxxxxxxxxxxxx` |

#### Использование API:

**Метод 1: JWT токен (через Web UI)**
1. Открыть `https://primelevel.group:7041`
2. Ввести `admin` / `xxxxxxxxxxxxxx`
3. Токен автоматически сохраняется в браузере на 24 часа (`TOKEN_EXPIRE_HOURS=24`)

**Метод 2: API Key (для программного доступа)**
```bash
# Одинаковый для всех workspaces
curl -X POST "https://primelevel.group:7041/documents/text" \
  -H "X-API-Key: xxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test document"}' -k
```

---

### 📊 Итоговая таблица доступа

#### Текущая конфигурация (после следования WORKSPACE-INFO.md):

| Workspace | URL | Username | Password | API Key | Изоляция данных |
|-----------|-----|----------|----------|---------|-----------------|
| Default | `https://primelevel.group:7040` | `admin` | `xxxxxxxxxxxxxx` | `xxxxxxxxxxxxxx` | ✅ 100% |
| Project A | `https://primelevel.group:7041` | `admin` | `xxxxxxxxxxxxxx` | `xxxxxxxxxxxxxx` | ✅ 100% |
| Project B | `https://primelevel.group:7042` | `admin` | `xxxxxxxxxxxxxx` | `xxxxxxxxxxxxxx` | ✅ 100% |

**Важно:** Все workspaces используют общие учетные данные, но **данные полностью изолированы** на уровне LightRAG.

---

### 🧪 Тестирование изоляции после настройки

```bash
# 1. Добавить документ в Default workspace
curl -X POST "https://primelevel.group:7040/documents/text" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: xxxxxxxxxxxxxx" \
  -d '{"text": "Document in DEFAULT workspace"}' -k

# 2. Добавить документ в Project A
curl -X POST "https://primelevel.group:7041/documents/text" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: xxxxxxxxxxxxxx" \
  -d '{"text": "Document in PROJECT A workspace"}' -k

# 3. Проверить изоляцию - Project A НЕ должен видеть документы Default
curl -X GET "https://primelevel.group:7041/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.items[] | .content'
# Ожидаемый результат: только "Document in PROJECT A workspace"

# 4. Проверить изоляцию - Default НЕ должен видеть документы Project A
curl -X GET "https://primelevel.group:7040/documents" \
  -H "X-API-Key: xxxxxxxxxxxxxx" -k | jq '.items[] | .content'
# Ожидаемый результат: только "Document in DEFAULT workspace"
```

---

**Дата создания документа:** 2025-10-16
**Последнее обновление:** 2025-10-16
**Версия LightRAG:** `ghcr.io/hkuds/lightrag:latest`
**Автор:** AI Assistant
**Проект:** ai_project (primelevel.group)
