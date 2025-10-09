# 📚 LightRAG API - Полное руководство по использованию

## 📋 Содержание
- [Общая информация](#общая-информация)
- [Аутентификация](#-аутентификация)
- [Управление документами](#-управление-документами)
- [Запросы к базе знаний](#-запросы-к-базе-знаний)
- [Работа с графом знаний](#-работа-с-графом-знаний)
- [Мониторинг и статус](#-мониторинг-и-статус)
- [Примеры использования из разных сервисов](#-примеры-использования-из-разных-сервисов)

---

## Общая информация

### 🌐 Доступ к LightRAG API

**Внешний доступ (из браузера/интернета):**
```bash
https://social.aigain.io:7040              # API endpoint
https://social.aigain.io:7040/docs         # Swagger документация
https://social.aigain.io:7040/redoc        # ReDoc документация
```

**Внутренний доступ (из других Docker контейнеров):**
```bash
http://lightrag:9621                       # По имени сервиса
http://service_lightrag:9621               # По имени контейнера
```

### 🔐 Аутентификация

LightRAG поддерживает **два метода аутентификации**:

| Метод | Заголовок | Когда использовать |
|-------|-----------|-------------------|
| **JWT** | `Authorization: Bearer <token>` | Веб-интерфейс, пользовательские сессии |
| **API Key** | `X-API-Key: <key>` | Автоматизация, скрипты, интеграции |

> 💡 **Для максимальной безопасности** настраивайте оба метода одновременно!

---

## 🔑 Аутентификация

### Метод 1: JWT Authentication (рекомендуется для веб-интерфейса)

#### 1.1 Получение JWT токена

**Endpoint:** `POST /auth/login`

**Конфигурация в .env:**
```bash
AUTH_ACCOUNTS=admin:your-password        # Формат: username:password
TOKEN_SECRET=your-secret-key-32chars     # Секретный ключ для JWT
TOKEN_EXPIRE_HOURS=24                    # Время жизни токена (по умолчанию 4)
```

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "your-password"
  }'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "your-password"
  }'
```

**Ответ:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

#### 1.2 Использование JWT токена

**С JWT токеном в заголовке Authorization:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{"query": "What is LightRAG?"}'
```

---

### Метод 2: API Key Authentication (рекомендуется для автоматизации)

#### 2.1 Настройка API Key

**Конфигурация в .env:**
```bash
LIGHTRAG_API_KEY=your-api-key-here       # API ключ для прямого доступа
WHITELIST_PATHS=/health,/api/*           # Пути без аутентификации
```

> 💡 **WHITELIST_PATHS** позволяет исключить определенные endpoints из проверки API Key:
> - `/health` - проверка здоровья (всегда доступен)
> - `/api/*` - Ollama emulation endpoints (если используете)

#### 2.2 Использование API Key

**С API Key в заголовке X-API-Key:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "X-API-Key: your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"query": "What is LightRAG?"}'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/documents/scan" \
  -H "X-API-Key: your-api-key-here" \
  -H "accept: application/json" \
  -d ''
```

---

### Сравнение методов аутентификации

| Характеристика | JWT | API Key |
|---------------|-----|---------|
| **Настройка** | Требует логин | Прямой доступ |
| **Истечение** | Да (TOKEN_EXPIRE_HOURS) | Нет |
| **Безопасность** | Выше (токены истекают) | Ниже (постоянный ключ) |
| **Использование** | Браузеры, веб-приложения | Скрипты, API интеграции |
| **Заголовок** | `Authorization: Bearer <token>` | `X-API-Key: <key>` |
| **Обновление** | Требуется re-login | Не требуется |

**Примеры использования:**

**JWT - для веб-приложения:**
```javascript
// Сначала логин
const loginResponse = await fetch('https://social.aigain.io:7040/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username: 'admin', password: 'pass' })
});
const { access_token } = await loginResponse.json();

// Затем запросы с токеном
const queryResponse = await fetch('https://social.aigain.io:7040/query', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${access_token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ query: 'What is LightRAG?' })
});
```

**API Key - для автоматизации:**
```bash
#!/bin/bash
API_KEY="your-api-key-here"

# Прямой запрос без логина
curl -X POST "https://social.aigain.io:7040/query" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "What is LightRAG?"}'
```

---

## 📄 Управление документами

### 1. Загрузка файлов (Upload Document)

**Endpoint:** `POST /documents/upload`

Поддерживаемые форматы: PDF, TXT, DOCX, CSV, JSON

**Из внешнего мира (с JWT):**
```bash
curl -X POST "https://social.aigain.io:7040/documents/upload" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/document.pdf"
```

**Из внешнего мира (с API Key):**
```bash
curl -X POST "https://social.aigain.io:7040/documents/upload" \
  -H "X-API-Key: your-api-key" \
  -F "file=@/path/to/document.pdf"
```

**Из Docker контейнера (с JWT):**
```bash
curl -X POST "http://lightrag:9621/documents/upload" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/app/data/inputs/document.pdf"
```

**Из Docker контейнера (с API Key):**
```bash
curl -X POST "http://lightrag:9621/documents/upload" \
  -H "X-API-Key: your-api-key" \
  -F "file=@/app/data/inputs/document.pdf"
```

**Ответ:**
```json
{
  "track_id": "abc123xyz789",
  "message": "Document uploaded successfully"
}
```

> 💡 **Важно:** Сохраните `track_id` для отслеживания прогресса обработки!

---

### 2. Вставка текста (Insert Text)

**Endpoint:** `POST /documents/text`

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/documents/text" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "text": "LightRAG is a powerful knowledge graph and RAG system designed for efficient document processing and intelligent query answering.",
    "metadata": {
      "source": "api",
      "category": "description",
      "date": "2025-10-09"
    }
  }'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/documents/text" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "text": "Your document text here...",
    "metadata": {
      "source": "internal",
      "topic": "example"
    }
  }'
```

**Ответ:**
```json
{
  "track_id": "def456uvw012",
  "message": "Text inserted successfully"
}
```

---

### 3. Вставка нескольких текстов (Insert Multiple Texts)

**Endpoint:** `POST /documents/texts`

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/documents/texts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "texts": [
      "First piece of text about machine learning.",
      "Second piece of text about neural networks.",
      "Third piece of text about deep learning."
    ]
  }'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/documents/texts" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "texts": [
      "Document 1 content",
      "Document 2 content",
      "Document 3 content"
    ]
  }'
```

**Ответ:**
```json
{
  "track_id": "ghi789rst345",
  "message": "Texts inserted successfully"
}
```

---

### 4. Список документов (List Documents)

**Endpoint:** `GET /documents/list`

**Из внешнего мира:**
```bash
curl -X GET "https://social.aigain.io:7040/documents/list" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Из Docker контейнера:**
```bash
curl -X GET "http://lightrag:9621/documents/list" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Ответ:**
```json
{
  "documents": [
    {
      "id": "doc-abcde",
      "name": "document.pdf",
      "status": "processed",
      "created_at": "2025-10-09T10:00:00Z"
    },
    {
      "id": "doc-fghij",
      "name": "text_document.txt",
      "status": "processing",
      "created_at": "2025-10-09T10:05:00Z"
    }
  ]
}
```

---

### 5. Удаление документа (Delete Document)

**Endpoint:** `DELETE /documents/{doc_id}`

**Из внешнего мира:**
```bash
curl -X DELETE "https://social.aigain.io:7040/documents/doc-12345" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Из Docker контейнера:**
```bash
curl -X DELETE "http://lightrag:9621/documents/doc-12345" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Ответ:**
```json
{
  "message": "Document deleted successfully"
}
```

---

### 6. Сканирование папки inputs (Scan Directory)

**Endpoint:** `POST /documents/scan`

Запускает сканирование папки `/app/data/inputs` для обработки новых документов.

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/documents/scan" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "accept: application/json"
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/documents/scan" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d ''
```

**Ответ:**
```json
{
  "message": "Directory scan initiated",
  "files_found": 5
}
```

---

## 🔍 Запросы к базе знаний

### Режимы поиска (Query Modes)

LightRAG поддерживает 6 режимов запросов:

| Режим | Описание | Использование |
|-------|----------|---------------|
| **naive** | Простой базовый поиск | Быстрые фактические запросы |
| **local** | Фокус на локальном контексте | Вопросы о конкретных сущностях |
| **global** | Использует глобальные знания | Вопросы о связях и паттернах |
| **hybrid** | Комбинация local + global | **Рекомендуется по умолчанию** |
| **mix** | Граф знаний + векторный поиск | Максимальная полнота результатов |
| **bypass** | Обход RAG, прямой запрос к LLM | Специальные случаи |

---

### 1. Базовый запрос (Query)

**Endpoint:** `POST /query`

Комплексный RAG endpoint с поддержкой различных режимов поиска для интеллектуальных ответов на основе базы знаний.

#### Параметры запроса:

| Параметр | Тип | Обязательно | Возможные значения | Описание |
|----------|-----|-------------|-------------------|----------|
| `query` | string | ✅ Да | Любой текст (мин. 3 символа) | Текст вопроса или запроса |
| `mode` | string | ❌ Нет | `local` \| `global` \| `hybrid` \| `naive` \| `mix` \| `bypass` | Режим поиска (по умолчанию: `hybrid`) |
| `top_k` | integer | ❌ Нет | `1` - `200+` | Количество результатов (по умолчанию: `50`) |
| `enable_rerank` | boolean | ❌ Нет | `true` \| `false` | Переранжирование результатов (по умолчанию: `false`) |
| `include_references` | boolean | ❌ Нет | `true` \| `false` | Включить ссылки на источники (по умолчанию: `false`) |
| `response_type` | string | ❌ Нет | `Multiple Paragraphs` \| `Bullet Points` \| `Short Answer` \| `Detailed Explanation` \| `Step by Step` \| `Table` \| `Code` | Формат ответа (по умолчанию: не задано) |
| `conversation_history` | array | ❌ Нет | `[{"role": "user\|assistant", "content": "..."}]` | История диалога (по умолчанию: `[]`) |
| `max_total_tokens` | integer | ❌ Нет | `100` - `8000+` | Макс. токенов для ответа (по умолчанию: лимит модели) |
| `stream` | boolean | ❌ Нет | `true` \| `false` | Игнорируется (используйте `/query/stream`) |

#### Режимы поиска (mode):

| Режим | Описание | Рекомендации |
|-------|----------|--------------|
| `local` | Фокус на конкретных сущностях и их прямых связях | Вопросы о конкретных объектах/персонах |
| `global` | Анализ широких паттернов и связей в графе знаний | Тренды, закономерности, общие темы |
| `hybrid` | Комбинация local + global подходов | Универсальный режим |
| `naive` | Простой векторный поиск без графа знаний | Быстрые фактические запросы |
| `mix` | Интеграция графа знаний и векторного поиска | ⭐ **Рекомендуется для лучших результатов** |
| `bypass` | Прямой запрос к LLM без поиска в базе знаний | Общие вопросы без контекста |

---

#### Детальное описание параметров:

##### 1. **`query`** (string, обязательно)

**Описание:** Текст вашего вопроса или запроса.

**Требования:**
- Минимум 3 символа
- Максимум: зависит от `max_total_tokens`

**Best Practices:**
```bash
✅ Хорошо:
"What are the building elements in RdSAP specifications?"
"Explain the relationship between neural networks and deep learning"
"List all dwelling types mentioned in the document"

❌ Плохо:
"AI"  # Слишком короткий
"Tell me everything about everything"  # Слишком общий
```

---

##### 2. **`mode`** (string, опционально)

**Значение по умолчанию:** `"hybrid"`

**Варианты:** `local`, `global`, `hybrid`, `naive`, `mix`, `bypass`

**Best Practices по выбору режима:**

| Тип вопроса | Рекомендуемый режим | Пример |
|-------------|---------------------|--------|
| О конкретном объекте/персоне | `local` | "Who is Alice?" |
| О трендах/паттернах | `global` | "What are AI research trends?" |
| Универсальные вопросы | `hybrid` | "Explain machine learning" |
| Быстрый фактический поиск | `naive` | "What is the capital of France?" |
| Сложные аналитические вопросы | `mix` ⭐ | "Compare transformers with RNNs" |
| Общий вопрос без контекста | `bypass` | "Write a poem about AI" |

**Рекомендации:**
```bash
# Для большинства случаев используйте mix
{
  "query": "Your question",
  "mode": "mix"
}

# Для быстрых запросов - naive
{
  "query": "Quick fact",
  "mode": "naive",
  "top_k": 10
}

# Для исследовательских вопросов - hybrid с rerank
{
  "query": "Complex analysis question",
  "mode": "hybrid",
  "top_k": 60,
  "enable_rerank": true
}
```

---

##### 3. **`top_k`** (integer, опционально)

**Значение по умолчанию:** `50`

**Диапазон:** `1` до `200+` (практически ограничен производительностью)

**Что означает в разных режимах:**

| Режим | `top_k` означает | Рекомендуемые значения |
|-------|------------------|------------------------|
| `local` | Количество **entities** (сущностей) | 30-60 |
| `global` | Количество **relationships** (связей) | 40-80 |
| `hybrid` | Entities + Relationships (~N/2 каждого) | 50-100 |
| `naive` | Количество **text chunks** | 10-30 |
| `mix` | Комбинация chunks + graph nodes | 60-120 |
| `bypass` | Игнорируется | N/A |

**Влияние на производительность:**

| `top_k` | Скорость | Качество | Стоимость (токены) | Когда использовать |
|---------|----------|----------|--------------------|--------------------|
| **5-10** | ⚡⚡⚡⚡⚡ | ⭐⭐ | 💰 | Очень быстрые ответы |
| **20-30** | ⚡⚡⚡⚡ | ⭐⭐⭐ | 💰💰 | Стандартные вопросы |
| **50-60** | ⚡⚡⚡ | ⭐⭐⭐⭐ | 💰💰💰 | **Рекомендуется** |
| **80-100** | ⚡⚡ | ⭐⭐⭐⭐⭐ | 💰💰💰💰 | Сложные запросы |
| **150+** | ⚡ | ⭐⭐⭐⭐⭐ | 💰💰💰💰💰 | Исследовательская работа |

**Best Practices:**
```bash
# Быстрый поиск фактов
{
  "mode": "naive",
  "top_k": 10
}

# Стандартный запрос (РЕКОМЕНДУЕТСЯ)
{
  "mode": "mix",
  "top_k": 60,
  "enable_rerank": true  # ВАЖНО при больших top_k!
}

# Глубокий анализ
{
  "mode": "hybrid",
  "top_k": 100,
  "enable_rerank": true  # ОБЯЗАТЕЛЬНО!
}

# Максимальная полнота (медленно, дорого)
{
  "mode": "mix",
  "top_k": 150,
  "enable_rerank": true
}
```

---

##### 4. **`enable_rerank`** (boolean, опционально)

**Значение по умолчанию:** `false` (или значение из `.env`: `RERANK_BY_DEFAULT`)

**Что делает:**
- `true`: После retrieval результаты **пересортируются** rerank-моделью по релевантности
- `false`: Результаты передаются в LLM без дополнительной обработки

**Провайдеры Rerank:**
- Cohere (rerank-english-v3.0) - рекомендуется
- Aliyun (gte-rerank-v2)
- Jina AI (jina-reranker-v2-base)

**Best Practices:**

```bash
✅ ВКЛЮЧАЙТЕ rerank когда:
- top_k >= 30 (фильтрует "шум")
- Технические документы (важна точность)
- Большая база знаний (1000+ документов)
- Сложные вопросы (нужна высокая релевантность)

❌ ВЫКЛЮЧАЙТЕ rerank когда:
- top_k <= 10 (нечего фильтровать)
- Простые вопросы (достаточно векторного поиска)
- Нужна максимальная скорость (rerank добавляет 0.5-2 сек)
- Экономия API calls (rerank = дополнительный запрос)
```

**Пример влияния:**
```bash
# БЕЗ rerank
{
  "top_k": 60,
  "enable_rerank": false
}
# → Результаты: 60 документов (могут быть нерелевантные)
# → Скорость: Быстро
# → Качество: Среднее

# С rerank (РЕКОМЕНДУЕТСЯ)
{
  "top_k": 60,
  "enable_rerank": true
}
# → Результаты: 60 документов, ПЕРЕСОРТИРОВАННЫЕ по релевантности
# → Скорость: +0.5-2 сек
# → Качество: Высокое
```

**Золотое правило:**
> 💡 **Если `top_k >= 30`, ВСЕГДА используйте `enable_rerank: true`**

---

##### 5. **`include_references`** (boolean, опционально)

**Значение по умолчанию:** `false`

**Что делает:**
- `true`: Ответ включает ссылки на источники (файлы, из которых взята информация)
- `false`: Только текст ответа без ссылок

**Best Practices:**
```bash
✅ Включайте references когда:
- Нужна проверка источников
- Работа с регулируемыми документами
- Академические/исследовательские запросы
- Требуется трассируемость

❌ Выключайте когда:
- Нужен только быстрый ответ
- Пользовательский чат (не нужны технические детали)
- Экономия токенов
```

**Пример:**
```bash
# Без ссылок
{
  "query": "What is AI?",
  "include_references": false
}
# Ответ:
{
  "response": "AI is artificial intelligence..."
}

# Со ссылками
{
  "query": "What is AI?",
  "include_references": true
}
# Ответ:
{
  "response": "AI is artificial intelligence...\n\n### References\n* [1] ai_basics.pdf\n* [2] ml_guide.txt",
  "references": [
    {"reference_id": "1", "file_path": "ai_basics.pdf"},
    {"reference_id": "2", "file_path": "ml_guide.txt"}
  ]
}
```

---

##### 6. **`response_type`** (string, опционально)

**Значение по умолчанию:** Не задано (LLM решает сам)

**Возможные значения:**
- `"Multiple Paragraphs"` - развернутый ответ с абзацами
- `"Bullet Points"` - список с маркерами
- `"Short Answer"` - краткий ответ
- `"Detailed Explanation"` - подробное объяснение
- `"Step by Step"` - пошаговая инструкция
- `"Table"` - табличный формат
- `"Code"` - ответ с примерами кода

**Best Practices:**
```bash
# Для списков
{
  "query": "List main components of neural networks",
  "response_type": "Bullet Points"
}

# Для объяснений
{
  "query": "Explain how transformers work",
  "response_type": "Multiple Paragraphs"
}

# Для инструкций
{
  "query": "How to configure LightRAG?",
  "response_type": "Step by Step"
}

# Для сравнений
{
  "query": "Compare RNN, LSTM, and Transformers",
  "response_type": "Table"
}

# Для технических вопросов
{
  "query": "Show how to use LightRAG API",
  "response_type": "Code"
}
```

---

##### 7. **`conversation_history`** (array, опционально)

**Значение по умолчанию:** `[]` (пустой массив)

**Формат:**
```json
[
  {"role": "user", "content": "Previous question"},
  {"role": "assistant", "content": "Previous answer"},
  {"role": "user", "content": "Follow-up question"}
]
```

**⚠️ ВАЖНО:**
> `conversation_history` передается **только в LLM** и **НЕ влияет** на retrieval (поиск в базе знаний). Для поиска используется только текущий `query`.

**Best Practices:**
```bash
✅ Используйте когда:
- Контекстные вопросы ("Расскажи подробнее", "А что насчет X?")
- Многошаговые диалоги
- Уточняющие вопросы

❌ Не используйте когда:
- Независимые запросы
- Первый вопрос в сессии
- История слишком длинная (>10 сообщений = много токенов)
```

**Пример:**
```bash
# Первый запрос (без истории)
{
  "query": "What is machine learning?"
}

# Последующий запрос (с историей)
{
  "query": "Can you give me more details about supervised learning?",
  "conversation_history": [
    {"role": "user", "content": "What is machine learning?"},
    {"role": "assistant", "content": "Machine learning is a subset of AI..."}
  ]
}

# Третий запрос
{
  "query": "Show me an example",
  "conversation_history": [
    {"role": "user", "content": "What is machine learning?"},
    {"role": "assistant", "content": "Machine learning is..."},
    {"role": "user", "content": "Can you give me more details about supervised learning?"},
    {"role": "assistant", "content": "Supervised learning is..."}
  ]
}
```

**Ограничение истории:**
```bash
# Плохо: Слишком длинная история (>10 сообщений)
conversation_history: [20 messages]  # Много токенов!

# Хорошо: Ограничить последними 6-8 сообщениями
conversation_history: [last 6 messages]  # Оптимально
```

---

##### 8. **`max_total_tokens`** (integer, опционально)

**Значение по умолчанию:** Не задано (используется лимит модели)

**Что делает:**
Ограничивает максимальное количество токенов для **всего ответа** (включая контекст + генерацию).

**Best Practices:**
```bash
# Краткие ответы
{
  "query": "Quick summary",
  "max_total_tokens": 300
}

# Стандартные ответы
{
  "query": "Explain the concept",
  "max_total_tokens": 1000
}

# Подробные ответы
{
  "query": "Detailed analysis",
  "max_total_tokens": 3000
}

# Максимальные ответы (осторожно с токенами!)
{
  "query": "Comprehensive review",
  "max_total_tokens": 8000
}
```

**Рекомендации:**
- **Чат-боты:** 500-1000 токенов
- **Документация:** 1000-2000 токенов
- **Исследования:** 2000-4000 токенов
- **Отчеты:** 4000-8000 токенов

---

#### 🎯 Best Practice комбинации параметров:

##### Scenario 1: Быстрый чат-бот
```json
{
  "query": "User question",
  "mode": "naive",
  "top_k": 10,
  "enable_rerank": false,
  "include_references": false,
  "max_total_tokens": 500
}
```
**Характеристики:** ⚡ Очень быстро, 💰 Дешево, ⭐⭐ Базовое качество

---

##### Scenario 2: Стандартный поиск (РЕКОМЕНДУЕТСЯ)
```json
{
  "query": "User question",
  "mode": "mix",
  "top_k": 60,
  "enable_rerank": true,
  "include_references": false,
  "response_type": "Multiple Paragraphs"
}
```
**Характеристики:** ⚡⚡⚡ Средняя скорость, 💰💰 Средняя цена, ⭐⭐⭐⭐ Отличное качество

---

##### Scenario 3: Технический поиск с источниками
```json
{
  "query": "Technical question",
  "mode": "hybrid",
  "top_k": 80,
  "enable_rerank": true,
  "include_references": true,
  "response_type": "Detailed Explanation"
}
```
**Характеристики:** ⚡⚡ Медленно, 💰💰💰 Дорого, ⭐⭐⭐⭐⭐ Максимальное качество

---

##### Scenario 4: Исследовательский анализ
```json
{
  "query": "Research question",
  "mode": "mix",
  "top_k": 120,
  "enable_rerank": true,
  "include_references": true,
  "response_type": "Multiple Paragraphs",
  "max_total_tokens": 4000
}
```
**Характеристики:** ⚡ Очень медленно, 💰💰💰💰 Очень дорого, ⭐⭐⭐⭐⭐ Превосходное качество

---

##### Scenario 5: Контекстный диалог
```json
{
  "query": "Follow-up question",
  "mode": "mix",
  "top_k": 40,
  "enable_rerank": true,
  "conversation_history": [
    {"role": "user", "content": "Previous question"},
    {"role": "assistant", "content": "Previous answer"}
  ]
}
```
**Характеристики:** ⚡⚡⚡ Средняя скорость, 💰💰💰 Средняя-высокая цена, ⭐⭐⭐⭐ Отличное качество с контекстом

---

> 💡 **Золотые правила:**
> 1. **Для 90% случаев:** `mode="mix"`, `top_k=60`, `enable_rerank=true`
> 2. **Если `top_k >= 30`:** ВСЕГДА `enable_rerank=true`
> 3. **Технические вопросы:** `include_references=true`
> 4. **Контекстные вопросы:** Ограничивайте `conversation_history` до 6-8 последних сообщений
> 5. **Большие `top_k`:** Обязательно включайте rerank

---

#### Примеры использования:

##### 1.1 Базовый запрос

**С JWT аутентификацией:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "What is machine learning?",
    "mode": "mix"
  }'
```

**С API Key аутентификацией:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "query": "What is machine learning?",
    "mode": "mix"
  }'
```

**Ответ:**
```json
{
  "response": "Machine learning is a subset of artificial intelligence...",
  "references": []
}
```

---

##### 1.2 Продвинутый запрос с ссылками

**С включенными ссылками на источники:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "query": "Explain neural networks",
    "mode": "hybrid",
    "include_references": true,
    "response_type": "Multiple Paragraphs",
    "top_k": 10,
    "enable_rerank": true
  }'
```

**Ответ:**
```json
{
  "response": "Neural networks are computing systems inspired by biological neural networks...\n\n### References\n* [1] document.pdf\n* [2] article.txt",
  "references": [
    {
      "reference_id": "1",
      "file_path": "document.pdf"
    },
    {
      "reference_id": "2",
      "file_path": "article.txt"
    }
  ]
}
```

---

##### 1.3 Запрос с историей диалога

**Контекстный запрос с предыдущей беседой:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "query": "Can you give me more details?",
    "mode": "mix",
    "conversation_history": [
      {
        "role": "user",
        "content": "What is artificial intelligence?"
      },
      {
        "role": "assistant",
        "content": "Artificial intelligence is the simulation of human intelligence by machines..."
      }
    ]
  }'
```

**Ответ:**
```json
{
  "response": "Certainly! To expand on artificial intelligence...",
  "references": []
}
```

---

##### 1.4 Запрос с ограничением токенов

**Контроль размера ответа:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "query": "Explain deep learning in detail",
    "mode": "mix",
    "max_total_tokens": 500,
    "include_references": true
  }'
```

---

##### 1.5 Запрос с форматированием ответа

**Указание желаемого формата:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "query": "List the main components of a neural network",
    "mode": "hybrid",
    "response_type": "Bullet Points",
    "top_k": 15
  }'
```

**Ответ:**
```json
{
  "response": "• Input Layer: Receives raw data\n• Hidden Layers: Process information\n• Output Layer: Produces final result\n• Weights: Connection strengths\n• Activation Functions: Non-linear transformations",
  "references": []
}
```

---

##### 1.6 Полный максимальный запрос со всеми параметрами

> ⚠️ **Обязательный параметр:** Только `query` (все остальные опциональны)

**Демонстрация всех доступных параметров API (для справки и тестирования):**

```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "query": "Explain the relationship between neural networks and deep learning, with practical examples",
    "mode": "mix",
    "top_k": 80,
    "chunk_top_k": 30,
    "enable_rerank": true,
    "include_references": true,
    "response_type": "Multiple Paragraphs",
    "max_total_tokens": 4000,
    "max_entity_tokens": 8000,
    "max_relation_tokens": 10000,
    "user_prompt": "Please provide practical code examples where applicable and explain concepts in a beginner-friendly manner",
    "conversation_history": [
      {
        "role": "user",
        "content": "What is machine learning?"
      },
      {
        "role": "assistant",
        "content": "Machine learning is a subset of artificial intelligence that enables systems to learn and improve from experience without being explicitly programmed. It uses algorithms to parse data, learn from it, and make predictions or decisions."
      },
      {
        "role": "user",
        "content": "Can you explain supervised learning?"
      },
      {
        "role": "assistant",
        "content": "Supervised learning is a type of machine learning where the model is trained on labeled data. The algorithm learns to map inputs to outputs based on example input-output pairs. Common tasks include classification and regression."
      }
    ]
  }'
```

**Описание параметров:**

| Параметр | Обязательный | Значение | Назначение |
|----------|--------------|----------|------------|
| `query` | ✅ **ДА** | string | **Основной вопрос** - текущий запрос пользователя |
| `mode` | ❌ Нет | `"mix"` | **Режим поиска** - комбинация графа знаний и векторного поиска (по умолчанию: `"hybrid"`) |
| `top_k` | ❌ Нет | `80` | **Количество результатов** - entities/relations для retrieval (по умолчанию: `60`) |
| `chunk_top_k` | ❌ Нет | `30` | **Количество чанков** - текстовых фрагментов после rerank (по умолчанию: `20`) |
| `enable_rerank` | ❌ Нет | `true` | **Reranking** - пересортировка результатов по релевантности (по умолчанию: `true`) |
| `include_references` | ❌ Нет | `true` | **Ссылки на источники** - добавить references в ответ (по умолчанию: `false`) |
| `response_type` | ❌ Нет | `"Multiple Paragraphs"` | **Формат ответа** - развернутый текст с абзацами (по умолчанию: не задано) |
| `max_total_tokens` | ❌ Нет | `4000` | **Лимит токенов** - максимум для всего контекста (по умолчанию: `30000`) |
| `max_entity_tokens` | ❌ Нет | `8000` | **Лимит entity** - токены для контекста сущностей (по умолчанию: `6000`) |
| `max_relation_tokens` | ❌ Нет | `10000` | **Лимит relations** - токены для контекста связей (по умолчанию: `8000`) |
| `user_prompt` | ❌ Нет | string | **Кастомная инструкция** - дополнительные указания для LLM (по умолчанию: не задано) |
| `conversation_history` | ❌ Нет | array | **История диалога** - предыдущие сообщения для контекста (по умолчанию: `[]`) |

**Ответ:**
```json
{
  "response": "Neural networks and deep learning are closely related concepts in artificial intelligence...\n\n[Detailed multi-paragraph explanation]\n\nPractical Example:\n```python\nimport tensorflow as tf\n# Neural network example code\n```\n\n### References\n* [1] neural_networks_guide.pdf\n* [2] deep_learning_fundamentals.txt\n* [3] ml_examples.md",
  "references": [
    {
      "reference_id": "1",
      "file_path": "neural_networks_guide.pdf",
      "score": 0.95
    },
    {
      "reference_id": "2",
      "file_path": "deep_learning_fundamentals.txt",
      "score": 0.89
    },
    {
      "reference_id": "3",
      "file_path": "ml_examples.md",
      "score": 0.85
    }
  ]
}
```

**💡 Важные замечания:**

1. **`conversation_history`** передается **только в LLM** для контекста, но **НЕ используется для retrieval** (поиск идет только по текущему `query`)

2. **Рекомендуемые комбинации для production:**
   - Для быстрых ответов: `top_k=30, chunk_top_k=10, enable_rerank=false`
   - Для качественных ответов: `top_k=60, chunk_top_k=20, enable_rerank=true` ⭐
   - Для максимальной полноты: `top_k=100, chunk_top_k=30, enable_rerank=true`

3. **Опциональные параметры** (можно не указывать):
   - Все параметры кроме `query` опциональны
   - Система использует значения по умолчанию из `.env` (TOP_K, CHUNK_TOP_K, и т.д.)

4. **История диалога** - ограничивайте до 6-8 последних сообщений для экономии токенов

---

#### Коды ошибок:

| Код | Описание | Причина |
|-----|----------|---------|
| `400` | Bad Request | Некорректные параметры (например, query < 3 символов) |
| `401` | Unauthorized | Отсутствует или неверная аутентификация |
| `500` | Internal Server Error | Ошибка обработки (например, LLM недоступен) |

---

### 2. Гибридный запрос с reranking (рекомендуется)

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "What are the building elements in RdSAP?",
    "mode": "hybrid",
    "top_k": 60,
    "enable_rerank": true
  }'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "Explain the relationship between dwelling types and building elements",
    "mode": "hybrid",
    "top_k": 50,
    "enable_rerank": true
  }'
```

> 💡 **Reranking** улучшает релевантность результатов, особенно для технических документов и больших баз знаний.

---

### 3. Локальный поиск (Local Mode)

Фокусируется на конкретных сущностях (entities).

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "Who is Alice?",
    "mode": "local",
    "top_k": 30
  }'
```

> 📌 В **local** режиме `top_k` = количество сущностей (entities) для поиска.

---

### 4. Глобальный поиск (Global Mode)

Анализирует связи между сущностями (relationships).

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "What are the trends in machine learning research?",
    "mode": "global",
    "top_k": 40
  }'
```

> 📌 В **global** режиме `top_k` = количество связей (relationships) для анализа.

---

### 5. Mix режим (максимальная полнота)

Комбинирует граф знаний и векторный поиск.

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "Explain RAG systems architecture",
    "mode": "mix",
    "top_k": 60,
    "enable_rerank": true
  }'
```

---

### 6. Стриминговый запрос (Streaming Query)

**Endpoint:** `POST /query/stream`

Возвращает ответ потоком в реальном времени (Server-Sent Events).

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/query/stream" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "Explain Retrieval-Augmented Generation",
    "mode": "hybrid",
    "stream": true
  }'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/query/stream" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "What is knowledge graph?",
    "mode": "local",
    "stream": true
  }'
```

**Ответ (потоковый):**
```json
{"token": "Retrieval-Augmented Generation (RAG)", "done": false}
{"token": " is a technique that combines", "done": false}
{"token": " retrieval systems with", "done": false}
{"token": " language models...", "done": false}
{"token": "\n", "done": true}
```

---

### 7. Использование префиксов в запросах

LightRAG поддерживает специальные префиксы для управления режимом поиска:

**Префиксы режимов:**
- `/local` - локальный поиск
- `/global` - глобальный поиск
- `/hybrid` - гибридный (по умолчанию)
- `/naive` - наивный
- `/mix` - смешанный
- `/bypass` - обход RAG, прямой запрос к LLM

**Префиксы контекста:**
- `/context` - вернуть только контекст
- `/localcontext` - локальный контекст
- `/globalcontext` - глобальный контекст
- `/hybridcontext` - гибридный контекст

**Пример с префиксом:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "/mix What is LightRAG?"
  }'
```

**Пример с user prompt:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "query": "/[Use mermaid format for diagrams] Please draw a character relationship diagram"
  }'
```

---

## 🕸️ Работа с графом знаний

### 1. Экспорт графа знаний (Export Graph)

**Endpoint:** `POST /graph/export`

**Из внешнего мира:**
```bash
curl -X POST "https://social.aigain.io:7040/graph/export" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "format": "csv",
    "include_vectors": false
  }'
```

**Из Docker контейнера:**
```bash
curl -X POST "http://lightrag:9621/graph/export" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "format": "json",
    "include_vectors": true
  }'
```

**Параметры:**
- `format` (string, опционально) - Формат экспорта: "csv", "json", "xml" (по умолчанию "csv")
- `include_vectors` (boolean, опционально) - Включить векторы в экспорт (по умолчанию false)

**Ответ (CSV):**
```csv
entity1,relationship,entity2,weight
Alice,knows,Bob,0.8
CompanyX,develops,AI software,0.95
```

**Ответ (JSON):**
```json
{
  "entities": [
    {"name": "Alice", "type": "Person"},
    {"name": "Bob", "type": "Person"},
    {"name": "CompanyX", "type": "Organization"}
  ],
  "relationships": [
    {"source": "Alice", "target": "Bob", "type": "knows", "weight": 0.8}
  ]
}
```

---

### 2. Получение детали сущности (Get Entity Details)

**Endpoint:** `GET /graph/entity/{entity_name}`

**Из внешнего мира:**
```bash
curl -X GET "https://social.aigain.io:7040/graph/entity/Alice" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Из Docker контейнера:**
```bash
curl -X GET "http://lightrag:9621/graph/entity/CompanyX" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Ответ:**
```json
{
  "entity": {
    "name": "Alice",
    "type": "Person",
    "attributes": {
      "age": 30,
      "occupation": "Engineer",
      "department": "AI Research"
    },
    "relationships": [
      {
        "target": "Bob",
        "type": "knows",
        "weight": 0.8
      },
      {
        "target": "CompanyX",
        "type": "works_at",
        "weight": 0.95
      }
    ]
  }
}
```

---

## 📊 Мониторинг и статус

### 1. Отслеживание статуса обработки (Track Status)

**Endpoint:** `GET /track_status/{track_id}`

После загрузки документа или вставки текста используйте `track_id` для отслеживания прогресса.

**Из внешнего мира:**
```bash
curl -X GET "https://social.aigain.io:7040/track_status/abc123xyz789" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Из Docker контейнера:**
```bash
curl -X GET "http://lightrag:9621/track_status/abc123xyz789" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Ответ:**
```json
{
  "status": "completed",
  "progress": 100,
  "message": "Document processed successfully.",
  "summary": "A brief summary of the document content...",
  "metadata": {
    "filename": "document.pdf",
    "pages": 10,
    "entities_extracted": 45,
    "relationships_found": 78
  },
  "created_at": "2025-10-09T10:00:00Z",
  "updated_at": "2025-10-09T10:05:00Z"
}
```

**Возможные статусы:**
- `PENDING` - В очереди на обработку
- `PROCESSING` - Обрабатывается
- `COMPLETED` - Успешно завершено
- `FAILED` - Ошибка обработки

---

### 2. Проверка здоровья (Health Check)

**Endpoint:** `GET /health`

> 💡 **Не требует аутентификации!**

**Из внешнего мира:**
```bash
curl -X GET "https://social.aigain.io:7040/health"
```

**Из Docker контейнера:**
```bash
curl -X GET "http://lightrag:9621/health"
```

**Ответ:**
```json
{
  "status": "ok",
  "version": "1.4.8",
  "uptime": "5 days, 3 hours",
  "documents_indexed": 1234,
  "storage_used": "2.5 GB"
}
```

---

## 🔗 Примеры использования из разных сервисов

### 1. Использование из Node-RED

**HTTP Request node:**

```javascript
// Настройки нода HTTP Request
{
  "method": "POST",
  "url": "http://lightrag:9621/query",
  "headers": {
    "Authorization": "Bearer YOUR_JWT_TOKEN",
    "Content-Type": "application/json"
  },
  "body": {
    "query": msg.payload,  // Запрос из входящего сообщения
    "mode": "hybrid",
    "top_k": 60,
    "enable_rerank": true
  }
}
```

**Function node для обработки ответа:**

```javascript
// Function node для парсинга результатов
const results = msg.payload.results;
const topResult = results[0];

msg.payload = {
  "answer": topResult.content,
  "source": topResult.source,
  "confidence": topResult.score
};

return msg;
```

**Пример flow для загрузки документа:**

```javascript
// Function node для подготовки данных
msg.payload = {
  "text": msg.payload,
  "metadata": {
    "source": "telegram",
    "user": msg.user,
    "timestamp": Date.now()
  }
};

msg.headers = {
  "Authorization": "Bearer " + env.get("LIGHTRAG_TOKEN"),
  "Content-Type": "application/json"
};

msg.url = "http://lightrag:9621/documents/text";
msg.method = "POST";

return msg;
```

---

### 2. Использование из Flowise AI

**Custom Tool или HTTP Request node:**

```javascript
const response = await fetch('http://lightrag:9621/query', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_JWT_TOKEN',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    query: $input,
    mode: 'hybrid',
    top_k: 60,
    enable_rerank: true
  })
});

const data = await response.json();
return data.results[0].content;
```

**Интеграция с LangChain:**

```javascript
import { CustomRetriever } from "langchain/retrievers/custom";

class LightRAGRetriever extends CustomRetriever {
  async _getRelevantDocuments(query) {
    const response = await fetch('http://lightrag:9621/query', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer YOUR_JWT_TOKEN',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        query: query,
        mode: 'hybrid',
        top_k: 10,
        enable_rerank: true
      })
    });

    const data = await response.json();
    return data.results.map(r => ({
      pageContent: r.content,
      metadata: { source: r.source, score: r.score }
    }));
  }
}
```

---

### 3. Использование из Python (внутри контейнера)

**Базовый пример:**

```python
import requests

# 1. Получение JWT токена
auth_response = requests.post(
    'http://lightrag:9621/auth/login',
    json={
        'username': 'admin',
        'password': 'xxxxxxxxxxxxxxx'
    }
)
token = auth_response.json()['access_token']

# 2. Заголовки для запросов
headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

# 3. Загрузка документа
with open('/path/to/document.pdf', 'rb') as f:
    upload_response = requests.post(
        'http://lightrag:9621/documents/upload',
        headers={'Authorization': f'Bearer {token}'},
        files={'file': f}
    )
    track_id = upload_response.json()['track_id']
    print(f"Track ID: {track_id}")

# 4. Вставка текста
text_response = requests.post(
    'http://lightrag:9621/documents/text',
    headers=headers,
    json={
        'text': 'LightRAG is a powerful knowledge graph system.',
        'metadata': {
            'source': 'python_script',
            'category': 'documentation'
        }
    }
)
print(f"Text Track ID: {text_response.json()['track_id']}")

# 5. Запрос к базе знаний
query_response = requests.post(
    'http://lightrag:9621/query',
    headers=headers,
    json={
        'query': 'What is LightRAG?',
        'mode': 'hybrid',
        'top_k': 60,
        'enable_rerank': True
    }
)
results = query_response.json()['results']
print(f"Answer: {results[0]['content']}")

# 6. Проверка статуса обработки
status_response = requests.get(
    f'http://lightrag:9621/track_status/{track_id}',
    headers=headers
)
status = status_response.json()
print(f"Status: {status['status']} ({status['progress']}%)")
```

**Асинхронный пример с aiohttp:**

```python
import aiohttp
import asyncio

async def lightrag_client():
    async with aiohttp.ClientSession() as session:
        # Получение токена
        async with session.post(
            'http://lightrag:9621/auth/login',
            json={'username': 'admin', 'password': 'your-password'}
        ) as resp:
            token = (await resp.json())['access_token']

        headers = {'Authorization': f'Bearer {token}'}

        # Параллельная вставка текстов
        texts = [
            "First document about AI",
            "Second document about ML",
            "Third document about RAG"
        ]

        tasks = []
        for text in texts:
            task = session.post(
                'http://lightrag:9621/documents/text',
                headers=headers,
                json={'text': text}
            )
            tasks.append(task)

        responses = await asyncio.gather(*tasks)
        track_ids = [await r.json() for r in responses]
        print(f"Inserted {len(track_ids)} documents")

        # Запрос
        async with session.post(
            'http://lightrag:9621/query',
            headers=headers,
            json={'query': 'Tell me about AI', 'mode': 'hybrid'}
        ) as resp:
            result = await resp.json()
            print(result)

asyncio.run(lightrag_client())
```

---

### 4. Использование из Bash скрипта

**Полный скрипт для автоматизации:**

```bash
#!/bin/bash

# Конфигурация
LIGHTRAG_URL="https://social.aigain.io:7040"
USERNAME="admin"
PASSWORD="xxxxxxxxxxxxxxx"

# 1. Получение JWT токена
echo "🔐 Authenticating..."
TOKEN=$(curl -s -X POST "${LIGHTRAG_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" \
  | jq -r '.access_token')

echo "✅ Token obtained: ${TOKEN:0:20}..."

# 2. Загрузка документа
echo "📄 Uploading document..."
TRACK_ID=$(curl -s -X POST "${LIGHTRAG_URL}/documents/upload" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "file=@/path/to/document.pdf" \
  | jq -r '.track_id')

echo "✅ Document uploaded. Track ID: ${TRACK_ID}"

# 3. Проверка статуса обработки
echo "⏳ Waiting for processing..."
while true; do
  STATUS=$(curl -s -X GET "${LIGHTRAG_URL}/track_status/${TRACK_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    | jq -r '.status')

  if [ "$STATUS" == "COMPLETED" ]; then
    echo "✅ Processing completed!"
    break
  elif [ "$STATUS" == "FAILED" ]; then
    echo "❌ Processing failed!"
    exit 1
  else
    echo "⏳ Status: ${STATUS}"
    sleep 5
  fi
done

# 4. Запрос к базе знаний
echo "🔍 Querying knowledge base..."
ANSWER=$(curl -s -X POST "${LIGHTRAG_URL}/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "query": "What is the main topic of the document?",
    "mode": "hybrid",
    "top_k": 60,
    "enable_rerank": true
  }' | jq -r '.results[0].content')

echo "📝 Answer: ${ANSWER}"

# 5. Список всех документов
echo "📚 Fetching document list..."
curl -s -X GET "${LIGHTRAG_URL}/documents/list" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq '.documents[] | {id, name, status}'
```

---

### 5. Использование из JavaScript/TypeScript (Browser или Node.js)

**TypeScript клиент:**

```typescript
interface LightRAGConfig {
  baseUrl: string;
  username: string;
  password: string;
}

class LightRAGClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(private config: LightRAGConfig) {
    this.baseUrl = config.baseUrl;
  }

  async authenticate(): Promise<void> {
    const response = await fetch(`${this.baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: this.config.username,
        password: this.config.password
      })
    });

    const data = await response.json();
    this.token = data.access_token;
  }

  private getHeaders(): HeadersInit {
    if (!this.token) throw new Error('Not authenticated');
    return {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json'
    };
  }

  async uploadDocument(file: File): Promise<string> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${this.baseUrl}/documents/upload`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${this.token}` },
      body: formData
    });

    const data = await response.json();
    return data.track_id;
  }

  async insertText(text: string, metadata?: Record<string, any>): Promise<string> {
    const response = await fetch(`${this.baseUrl}/documents/text`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ text, metadata })
    });

    const data = await response.json();
    return data.track_id;
  }

  async query(
    query: string,
    options: {
      mode?: string;
      top_k?: number;
      enable_rerank?: boolean;
    } = {}
  ): Promise<any> {
    const response = await fetch(`${this.baseUrl}/query`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        query,
        mode: options.mode || 'hybrid',
        top_k: options.top_k || 60,
        enable_rerank: options.enable_rerank !== false
      })
    });

    return await response.json();
  }

  async trackStatus(trackId: string): Promise<any> {
    const response = await fetch(`${this.baseUrl}/track_status/${trackId}`, {
      headers: this.getHeaders()
    });

    return await response.json();
  }

  async listDocuments(): Promise<any> {
    const response = await fetch(`${this.baseUrl}/documents/list`, {
      headers: this.getHeaders()
    });

    return await response.json();
  }

  async exportGraph(format: 'csv' | 'json' = 'json'): Promise<any> {
    const response = await fetch(`${this.baseUrl}/graph/export`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({ format, include_vectors: false })
    });

    return await response.json();
  }
}

// Использование
const client = new LightRAGClient({
  baseUrl: 'https://social.aigain.io:7040',
  username: 'admin',
  password: 'your-password'
});

await client.authenticate();

// Загрузка текста
const trackId = await client.insertText('LightRAG is awesome!');
console.log('Track ID:', trackId);

// Запрос
const results = await client.query('What is LightRAG?', {
  mode: 'hybrid',
  enable_rerank: true
});
console.log('Answer:', results.results[0].content);
```

---

## 📝 Дополнительные примеры

### Batch операции (массовая загрузка)

```bash
#!/bin/bash

TOKEN="YOUR_JWT_TOKEN"
URL="https://social.aigain.io:7040"

# Загрузка всех PDF файлов из папки
for file in /path/to/pdfs/*.pdf; do
  echo "Uploading: $(basename $file)"

  TRACK_ID=$(curl -s -X POST "${URL}/documents/upload" \
    -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${file}" \
    | jq -r '.track_id')

  echo "Track ID: ${TRACK_ID}"
  echo "${TRACK_ID}" >> track_ids.txt
done

echo "✅ All files uploaded!"
```

### Мониторинг обработки документов

```python
import requests
import time

def wait_for_completion(track_ids, token, base_url):
    """Ожидает завершения обработки всех документов"""
    headers = {'Authorization': f'Bearer {token}'}

    while track_ids:
        for track_id in track_ids[:]:  # Копия списка для итерации
            response = requests.get(
                f'{base_url}/track_status/{track_id}',
                headers=headers
            )
            status_data = response.json()

            status = status_data['status']
            progress = status_data['progress']

            print(f"[{track_id}] {status} - {progress}%")

            if status == 'COMPLETED':
                track_ids.remove(track_id)
                print(f"✅ {track_id} completed!")
            elif status == 'FAILED':
                track_ids.remove(track_id)
                print(f"❌ {track_id} failed: {status_data.get('error_message')}")

        if track_ids:
            time.sleep(5)

    print("🎉 All documents processed!")

# Использование
track_ids = ['track-1', 'track-2', 'track-3']
wait_for_completion(track_ids, 'YOUR_TOKEN', 'https://social.aigain.io:7040')
```

---

## 🎯 Советы по использованию

### 1. Выбор режима запроса

- **naive** - для простых фактических вопросов
- **local** - когда нужна информация о конкретных объектах/персонах
- **global** - для вопросов о связях, трендах, общих темах
- **hybrid** - универсальный режим (рекомендуется для большинства случаев)
- **mix** - когда нужна максимальная полнота результатов

### 2. Оптимизация параметров

- `top_k`:
  - 30-50 для быстрых запросов
  - 60-100 для более полных результатов
  - 100+ для сложных аналитических запросов

- `enable_rerank`:
  - `true` - для технических документов и больших баз знаний
  - `false` - для простых запросов (экономия API calls)

### 3. Batch операции

Для массовой загрузки документов используйте:
- `POST /documents/texts` для множественной вставки текстов
- Параллельные запросы для ускорения обработки
- Отслеживание `track_id` для мониторинга прогресса

### 4. Обработка ошибок

Всегда проверяйте статус ответа и обрабатывайте ошибки:

```python
try:
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()  # Выбросит исключение при HTTP ошибке
    result = response.json()
except requests.exceptions.HTTPError as e:
    print(f"HTTP Error: {e}")
except requests.exceptions.ConnectionError:
    print("Connection Error: Unable to reach LightRAG server")
except Exception as e:
    print(f"Error: {e}")
```

---

## 📚 Ресурсы

- **Swagger UI:** https://social.aigain.io:7040/docs
- **ReDoc:** https://social.aigain.io:7040/redoc
- **GitHub:** https://github.com/hkuds/lightrag
- **Docker Hub:** https://hub.docker.com/r/hkuds/lightrag

---

## 🔧 Конфигурация в проекте

Все настройки LightRAG находятся в файле `.env`:


