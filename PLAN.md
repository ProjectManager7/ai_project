# 📋 План внедрения приложения Chroma-API

**Версия:** 1.0
**Дата:** 06.10.2025
**Задача:** Миграция старого приложения chroma_api (запускалось на хосте через systemd) в Docker контейнер с интеграцией в текущую инфраструктуру

---

## 🎯 Цели проекта

1. **Контейнеризация:** Перенести приложение chroma_api из хостовой системы в Docker контейнер
2. **Безопасность:** Добавить проверку токена для доступа к API
3. **Интеграция:** Подключить к внутренней сети Docker для работы с service_chroma
4. **Доступность:** Пробросить через Traefik на внешний порт 8333 с SSL

---

## 📊 Анализ текущей инфраструктуры

### Старая архитектура (до миграции):
```
Internet → Nginx (host) → Gunicorn (host:3010) → ChromaDB (host)
              ↓
         SSL на порту 3011
```

**Проблемы старой архитектуры:**
- ❌ Зависимости установлены на хост
- ❌ Конфигурация захардкожена в коде
- ❌ Нет проверки токена безопасности
- ❌ Управление через systemd (нет изоляции)
- ❌ Сложность обновления и масштабирования

### Новая архитектура (после миграции):
```
Internet → Traefik (container) → Chroma-API (container) → ChromaDB (container)
              ↓                        ↓                         ↓
         SSL (8333)          API Token Check            Internal Network
```

**Преимущества новой архитектуры:**
- ✅ Полная контейнеризация
- ✅ Конфигурация через .env
- ✅ Проверка токена безопасности
- ✅ Изоляция и легкое управление
- ✅ Простое масштабирование

---

## 📁 Структура нового приложения

```
ai_project/
├── chroma-api/                          # 📂 Новая папка приложения
│   ├── app.py                           # Flask приложение
│   ├── routes.py                        # API endpoints (с проверкой токена + /health)
│   ├── chroma_utils.py                  # Утилиты для работы с ChromaDB
│   ├── readers.py                       # Чтение файлов (txt, pdf, docx, csv, json)
│   ├── wsgi.py                          # WSGI entry point
│   ├── __init__.py                      # Python package marker
│   ├── requirements.txt                 # 📄 Python зависимости
│   └── Dockerfile                       # 🐳 Docker образ (с HEALTHCHECK)
├── docker-compose.yml                   # ✏️ Обновить (добавить chroma-api сервис)
├── .env                                 # ✏️ Обновить (добавить новые переменные)
└── README.md                            # ✏️ Обновить (добавить документацию)
```

---

## 🔧 Этап 1: Подготовка переменных окружения

### Добавить в `.env`:

```bash
# ===========================================
# CHROMA-API CONFIGURATION
# ===========================================

# ChromaDB Connection (внутренняя сеть Docker)
CHROMA_SERVER_HOST=service_chroma         # Имя контейнера ChromaDB
CHROMA_SERVER_PORT=8000                   # Внутренний порт ChromaDB

# Chroma-API Settings
CHROMA_MODEL=text-embedding-3-large       # Модель для embeddings
CHROMA_DEFAULT_CHUNK_SIZE=1000            # Размер чанков текста
CHROMA_DEFAULT_CHUNK_OVERLAP=200          # Перекрытие чанков

# Security Token (для доступа к API)
CHROMA_API_TOKEN=123456xyz                # Секретный токен для API
```

**Примечание:** Переменная `OPENAI_API_KEY` уже есть в .env и будет использоваться для создания embeddings.

---

## 🐳 Этап 2: Создание Dockerfile

### Файл: `chroma-api/Dockerfile`

```dockerfile
FROM python:3.11-slim

# Установка системных зависимостей (включая curl для healthcheck)
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /app

# Копирование зависимостей
COPY requirements.txt .

# Установка Python пакетов
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY . .

# Открытие порта
EXPOSE 3010

# Health Check - проверка работоспособности контейнера
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3010/health || exit 1

# Запуск Gunicorn
CMD ["gunicorn", \
     "--workers", "4", \
     "--threads", "2", \
     "--bind", "0.0.0.0:3010", \
     "--timeout", "600", \
     "--graceful-timeout", "600", \
     "--keep-alive", "600", \
     "--log-level", "info", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "wsgi:app"]
```

**Особенности:**
- Python 3.11 для совместимости
- Gunicorn с 4 воркерами и 2 потоками
- Таймауты 600 секунд для длительных операций
- Логи выводятся в stdout/stderr (для Docker)
- **HEALTHCHECK** - автоматическая проверка работоспособности каждые 30 секунд

---

## 🔧 Этап 3: Создание requirements.txt

### Файл: `chroma-api/requirements.txt`

```txt
flask==3.0.0
chromadb==0.4.22
langchain==0.1.6
openai==1.10.0
langchain-community==0.0.20
langchain-openai==0.0.5
python-docx==1.1.0
PyPDF2==3.0.1
gunicorn==21.2.0
requests==2.31.0
tiktoken==0.5.2
```

**Зависимости:**
- `flask` - веб-фреймворк
- `chromadb` - клиент для ChromaDB
- `langchain` - для работы с текстом и разделения на чанки
- `openai` - для создания embeddings
- `python-docx`, `PyPDF2` - для чтения документов
- `gunicorn` - WSGI сервер
- `tiktoken` - токенизация текста

---

## 🔒 Этап 4: Добавление проверки токена и Health Check

### Изменения в `chroma-api/routes.py`:

**Добавить Health Check endpoint в начало файла (после импортов):**

```python
@app1.route('/health', methods=['GET'])
def health():
    """
    Health Check endpoint для Docker и Traefik
    Проверяет работоспособность API и подключение к ChromaDB
    """
    try:
        # Проверяем подключение к ChromaDB
        chroma_manager.client.heartbeat()
        return jsonify({
            "status": "healthy",
            "service": "chroma-api",
            "chroma_connected": True
        }), 200
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "service": "chroma-api",
            "chroma_connected": False,
            "error": str(e)
        }), 503
```

**Добавить проверку токена в начало функции `api()`:**

```python
@app1.route('/api', methods=['POST'])
def api():
    try:
        # 🔒 Проверка токена безопасности
        api_token = request.headers.get('x-chroma-api-token')
        expected_token = os.getenv('CHROMA_API_TOKEN')

        if not api_token or api_token != expected_token:
            error_msg = "Unauthorized: Invalid or missing API token"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 401

        # Остальной код...
```

**Обновить импорты:**
```python
import os  # Добавить в начало файла
```

---

## 🔧 Этап 5: Адаптация кода

### Изменения в `chroma-api/chroma_utils.py`:

**Удалить импорт config.py, использовать os.getenv() + Singleton паттерн:**

```python
import os
import threading

class ChromaManager:
    """
    Singleton класс для управления подключением к ChromaDB
    Использует Connection Pooling - создается только один экземпляр
    """
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        """Реализация Singleton паттерна с thread-safe инициализацией"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        """Инициализация выполняется только один раз"""
        if self._initialized:
            return

        # Чтение переменных из окружения
        host = os.getenv('CHROMA_SERVER_HOST', 'service_chroma')
        port = int(os.getenv('CHROMA_SERVER_PORT', '8000'))

        self.client = HttpClient(
            host=host,
            port=port,
            settings=Settings(anonymized_telemetry=False)
        )

        self._initialized = True
        logging.info(f"ChromaDB client initialized: {host}:{port}")

    def _create_embeddings(self, texts: List[str], api_key: Optional[str] = None,
                           model_name: Optional[str] = None) -> List[List[float]]:
        # Используем переменные из окружения
        api_key = api_key or os.getenv('OPENAI_API_KEY')
        model = model_name or os.getenv('CHROMA_MODEL', 'text-embedding-3-large')

        client = OpenAI(api_key=api_key)
        # ...
```

**Преимущества Singleton:**
- ✅ Только одно подключение к ChromaDB (экономия ресурсов)
- ✅ Thread-safe инициализация (безопасно для Gunicorn workers)
- ✅ Повторное использование соединения (быстрее)

### Изменения в `chroma-api/readers.py`:

**Обновить пути для безопасного доступа к файлам:**

```python
@staticmethod
def is_safe_path(path: str) -> bool:
    """
    Проверяет, безопасен ли путь к файлу
    """
    allowed_dirs = [
        '/app/data',              # Внутри контейнера
        '/data/shared'            # Общая папка (если нужна)
    ]

    abs_path = os.path.abspath(path)
    return any(abs_path.startswith(allowed_dir) for allowed_dir in allowed_dirs)
```

---

## 🐳 Этап 6: Обновление docker-compose.yml

### Добавить новый сервис:

```yaml
  # ===========================================
  # CHROMA API SERVICE
  # ===========================================
  chroma-api:
    build:
      context: ./chroma-api
      dockerfile: Dockerfile
    container_name: service_chroma_api
    restart: unless-stopped
    environment:
      - TZ=${TZ}
      - CHROMA_SERVER_HOST=${CHROMA_SERVER_HOST}
      - CHROMA_SERVER_PORT=${CHROMA_SERVER_PORT}
      - CHROMA_MODEL=${CHROMA_MODEL}
      - CHROMA_DEFAULT_CHUNK_SIZE=${CHROMA_DEFAULT_CHUNK_SIZE}
      - CHROMA_DEFAULT_CHUNK_OVERLAP=${CHROMA_DEFAULT_CHUNK_OVERLAP}
      - CHROMA_API_TOKEN=${CHROMA_API_TOKEN}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      - chroma
      - traefik
    networks:
      - internal
    volumes:
      - ./shared:/data/shared
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    labels:
      - "traefik.enable=true"

      # HTTP роутер с редиректом на HTTPS
      - "traefik.http.routers.chromaapi-http.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.chromaapi-http.entrypoints=web"
      - "traefik.http.routers.chromaapi-http.middlewares=chromaapi-https-redirect"

      # HTTPS роутер для Chroma-API на порту 8333
      - "traefik.http.routers.chromaapi-https.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.chromaapi-https.entrypoints=websecure-8333"
      - "traefik.http.routers.chromaapi-https.priority=80"
      - "traefik.http.routers.chromaapi-https.tls=true"
      - "traefik.http.routers.chromaapi-https.tls.certresolver=letsencrypt"

      # Middlewares - Rate Limiting и Compression
      - "traefik.http.middlewares.chromaapi-ratelimit.ratelimit.average=100"
      - "traefik.http.middlewares.chromaapi-ratelimit.ratelimit.burst=50"
      - "traefik.http.middlewares.chromaapi-ratelimit.ratelimit.period=1s"
      - "traefik.http.middlewares.chromaapi-compress.compress=true"

      # Применяем middlewares к HTTPS роутеру
      - "traefik.http.routers.chromaapi-https.middlewares=chromaapi-ratelimit,chromaapi-compress"

      # Сервис Chroma-API
      - "traefik.http.services.chromaapi.loadbalancer.server.port=3010"

      # Middleware для редиректа на HTTPS
      - "traefik.http.middlewares.chromaapi-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.middlewares.chromaapi-https-redirect.redirectscheme.port=8333"
```

**Добавленные middlewares:**
- **Rate Limiting:** 100 запросов/сек (средняя), burst до 50 запросов
- **Compression:** Автоматическое сжатие больших JSON ответов

### Добавить entrypoint для порта 8333 в Traefik:

**В `traefik/traefik.yml` добавить:**

```yaml
entryPoints:
  # ... существующие entrypoints ...

  websecure-8333:
    address: ":8333"
    http:
      tls:
        certResolver: letsencrypt
```

**В docker-compose.yml для traefik добавить порт:**

```yaml
  traefik:
    ports:
      - "80:80"
      - "127.0.0.1:8082:8080"
      - "443:443"
      - "5050:5050"
      - "7040:7040"
      - "8333:8333"          # Добавить этот порт
```

---

## 🧪 Этап 7: Тестирование

### 7.1. Сборка и запуск:

```bash
cd /root/ai_project

# Сборка нового контейнера
docker compose build chroma-api

# Запуск всех сервисов
docker compose up -d

# Проверка статуса
docker ps | grep chroma

# Проверка логов
docker logs service_chroma_api -f
```

### 7.2. Тестирование Health Check:

**Проверка работоспособности API:**
```bash
# Из хоста
curl http://localhost:3010/health

# Через Traefik (HTTPS)
curl https://social.aigain.io:8333/health

# Ожидаемый ответ:
# {
#   "status": "healthy",
#   "service": "chroma-api",
#   "chroma_connected": true
# }
```

**Проверка Docker healthcheck:**
```bash
# Статус контейнера должен показывать (healthy)
docker ps | grep chroma_api

# Детальная информация о healthcheck
docker inspect service_chroma_api | grep -A 10 Health
```

### 7.3. Тестирование API:

**Без токена (должна быть ошибка 401):**
```bash
curl -X POST https://social.aigain.io:8333/api \
-H "Content-Type: application/json" \
-d '{
    "action": "count",
    "collection_name": "test"
}'
```

**С токеном (должно работать):**
```bash
curl -X POST https://social.aigain.io:8333/api \
-H "Content-Type: application/json" \
-H "x-chroma-api-token: 123456xyz" \
-d '{
    "action": "count",
    "collection_name": "test"
}'
```

### 7.3. Тест загрузки документа:

```bash
curl -X POST https://social.aigain.io:8333/api \
-H "Content-Type: application/json" \
-H "x-chroma-api-token: 123456xyz" \
-d '{
    "action": "upsert",
    "file_name": "https://example.com/document.txt",
    "collection_name": "test"
}'
```

### 7.4. Тест RAG запроса:

```bash
curl -X POST https://social.aigain.io:8333/api \
-H "Content-Type: application/json" \
-H "x-chroma-api-token: 123456xyz" \
-d '{
    "action": "query",
    "collection_name": "test",
    "query": "What is this document about?",
    "n_results": 4
}'
```

---

## 📝 Этап 8: Документация

### Обновить README.md:

**Добавить секцию про Chroma-API:**

```markdown
## 🧠 Chroma-API - REST API для ChromaDB

**Chroma-API** - это REST API сервис для работы с векторной базой данных ChromaDB.

### 📋 Основные возможности:

- **📄 Загрузка документов** - поддержка txt, pdf, docx, csv, json
- **🔍 RAG запросы** - поиск релевантных документов с фильтрацией
- **🗑️ Управление коллекциями** - создание, удаление, просмотр
- **🔐 Безопасность** - проверка токена в headers
- **📊 Метаданные** - гибкая работа с метаданными документов

### 🌐 Доступ к сервису:

**Внешний доступ (из браузера/API):**
```bash
https://social.aigain.io:8333/api        # API endpoint
```

**Внутренний доступ (из других Docker контейнеров):**
```bash
http://service_chroma_api:3010/api       # По имени контейнера
```

### 🔑 Аутентификация:

Chroma-API использует проверку токена через header `x-chroma-api-token`.

**Пример запроса с токеном:**
```bash
curl -X POST https://social.aigain.io:8333/api \
  -H "Content-Type: application/json" \
  -H "x-chroma-api-token: YOUR_TOKEN_HERE" \
  -d '{
    "action": "query",
    "collection_name": "documents",
    "query": "What is machine learning?",
    "n_results": 5
  }'
```

### 📚 API Endpoints:

| Action | Описание | Параметры |
|--------|----------|-----------|
| `upsert` | Загрузка файла в коллекцию | file_name, collection_name, metadata |
| `upsert_json` | Загрузка JSON данных | json_data, collection_name, metadata |
| `query` | RAG поиск по коллекции | query, collection_name, n_results |
| `show_collection` | Показать содержимое коллекции | collection_name, filters |
| `count` | Подсчет документов | collection_name |
| `delete_file` | Удаление документов | collection_name, filters |
| `delete_collection` | Удаление коллекции | collection_name |

### 🔧 Конфигурация:

Все параметры настраиваются через `.env`:

```bash
# ChromaDB подключение
CHROMA_SERVER_HOST=service_chroma
CHROMA_SERVER_PORT=8000

# Настройки эмбеддингов
CHROMA_MODEL=text-embedding-3-large
CHROMA_DEFAULT_CHUNK_SIZE=1000
CHROMA_DEFAULT_CHUNK_OVERLAP=200

# Безопасность
CHROMA_API_TOKEN=your-secret-token
OPENAI_API_KEY=sk-your-openai-key
```

### 🚀 Примеры использования:

См. файл `chroma_api/Инструкции по запуску.txt` для детальных примеров всех endpoints.
```

---

## 🔥 Этап 9: Настройка Firewall (UFW)

**Открыть порт 8333 для внешнего доступа:**

```bash
sudo ufw allow 8333/tcp
sudo ufw reload
sudo ufw status
```

---

## ✅ Контрольный список (Checklist)

### Подготовка:
- [ ] Изучить структуру старого проекта
- [ ] Изучить текущий docker-compose.yml
- [ ] Изучить .env файл

### Создание файлов:
- [ ] Создать папку `chroma-api/`
- [ ] Создать `chroma-api/Dockerfile`
- [ ] Создать `chroma-api/requirements.txt`
- [ ] Скопировать и адаптировать `app.py`
- [ ] Скопировать и адаптировать `routes.py` (добавить проверку токена)
- [ ] Скопировать и адаптировать `chroma_utils.py` (использовать os.getenv)
- [ ] Скопировать и адаптировать `readers.py`
- [ ] Скопировать `wsgi.py`
- [ ] Создать `__init__.py`

### Конфигурация:
- [ ] Добавить переменные в `.env`
- [ ] Обновить `docker-compose.yml` (добавить сервис chroma-api)
- [ ] Обновить `traefik/traefik.yml` (добавить entrypoint 8333)
- [ ] Добавить порт 8333 в traefik ports

### Развертывание:
- [ ] Собрать Docker образ: `docker compose build chroma-api`
- [ ] Запустить контейнер: `docker compose up -d`
- [ ] Проверить логи: `docker logs service_chroma_api`
- [ ] Проверить статус: `docker ps | grep chroma`

### Тестирование:
- [ ] Тест без токена (должна быть ошибка 401)
- [ ] Тест с токеном (должно работать)
- [ ] Тест загрузки документа (upsert)
- [ ] Тест RAG запроса (query)
- [ ] Тест подсчета документов (count)
- [ ] Тест удаления (delete_file)

### Безопасность:
- [ ] Открыть порт 8333 в UFW
- [ ] Проверить работу токена аутентификации
- [ ] Проверить SSL сертификат
- [ ] Проверить доступ из внутренней сети Docker

### Документация:
- [ ] Обновить README.md
- [ ] Добавить примеры использования
- [ ] Документировать API endpoints

---

## 🚨 Возможные проблемы и решения

### Проблема 1: Контейнер не запускается

**Решение:**
```bash
# Проверить логи
docker logs service_chroma_api

# Проверить сборку
docker compose build chroma-api --no-cache

# Проверить переменные окружения
docker exec service_chroma_api env | grep CHROMA
```

### Проблема 2: Не подключается к ChromaDB

**Решение:**
```bash
# Проверить доступность service_chroma
docker exec service_chroma_api ping service_chroma

# Проверить порт ChromaDB
docker exec service_chroma_api nc -zv service_chroma 8000

# Проверить переменные CHROMA_SERVER_HOST и CHROMA_SERVER_PORT
```

### Проблема 3: SSL сертификат не работает

**Решение:**
```bash
# Проверить логи Traefik
docker logs service_traefik | grep 8333

# Проверить entrypoint
docker exec service_traefik cat /etc/traefik/traefik.yml | grep 8333

# Проверить порт
curl -I https://social.aigain.io:8333/api
```

### Проблема 4: Токен не работает

**Решение:**
```bash
# Проверить переменную CHROMA_API_TOKEN
docker exec service_chroma_api env | grep CHROMA_API_TOKEN

# Проверить код routes.py (должна быть проверка)
docker exec service_chroma_api cat /app/routes.py | grep api_token
```

---

## 📊 Мониторинг и логи

### Просмотр логов:

```bash
# Логи Chroma-API
docker logs service_chroma_api -f

# Логи Traefik (для проверки маршрутизации)
docker logs service_traefik | grep chromaapi

# Логи ChromaDB
docker logs service_chroma -f
```

### Проверка производительности:

```bash
# Использование ресурсов
docker stats service_chroma_api

# Проверка подключений
docker exec service_chroma_api netstat -an | grep 3010
```

---

## 🎯 Итоговая архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                ┌─────▼──────┐
                │   TRAEFIK  │ ◄─── SSL Termination (8333)
                │  (Proxy)   │      Token Check (optional)
                └─────┬──────┘
                      │
                ┌─────▼──────┐
                │ CHROMA-API │ ◄─── Flask + Gunicorn
                │ Container  │      Token Validation
                │  :3010     │      Document Processing
                └─────┬──────┘
                      │
                      │ Internal Network (service_chroma:8000)
                      │
                ┌─────▼──────┐
                │  ChromaDB  │ ◄─── Vector Database
                │ Container  │      Embeddings Storage
                │  :8000     │
                └────────────┘
```

**Ключевые компоненты:**
1. **Traefik** - SSL терминация, маршрутизация на порт 8333
2. **Chroma-API** - REST API с проверкой токена
3. **ChromaDB** - векторная база данных (внутренняя сеть)
4. **OpenAI API** - создание embeddings

---

## 📈 Следующие шаги (после внедрения)

1. **Мониторинг:** Настроить алерты для Chroma-API
2. **Backup:** Настроить резервное копирование коллекций ChromaDB
3. **Оптимизация:** Настроить кэширование запросов
4. **Масштабирование:** При необходимости увеличить количество воркеров
5. **Документация:** Создать подробную API документацию (Swagger/OpenAPI)

---

## 🔗 Полезные ссылки

- **ChromaDB Documentation:** https://docs.trychroma.com/
- **OpenAI Embeddings:** https://platform.openai.com/docs/guides/embeddings
- **Flask Documentation:** https://flask.palletsprojects.com/
- **Gunicorn Settings:** https://docs.gunicorn.org/en/stable/settings.html
- **Traefik Configuration:** https://doc.traefik.io/traefik/

---

**Конец плана**
