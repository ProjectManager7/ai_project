# LightRAG - Режимы поиска (Query Modes)

## 📋 Обзор

LightRAG - это система для работы с документами, построения графов знаний и Retrieval Augmented Generation (RAG). Система поддерживает 6 режимов запросов для различных сценариев поиска информации.

---

## 📌 Основные режимы (Query Modes)

### **1. Naive (Наивный)**
- **Описание**: Performs a basic search without advanced techniques
- **Простыми словами**: Простой базовый поиск без использования продвинутых техник
- **Особенности**:
  - Не использует граф знаний
  - Самый быстрый режим
  - Подходит для простых запросов
- **Когда использовать**: Простые фактические вопросы, быстрый поиск

---

### **2. Local (Локальный)**
- **Описание**: Focuses on context-dependent information
- **Простыми словами**: Фокусируется на контекстно-зависимой информации
- **Особенности**:
  - В этом режиме параметр `top_k` представляет количество **entities (сущностей)**
  - Использует локальный контекст вокруг найденных сущностей
  - Хорошо работает с конкретными объектами/персонами
- **Когда использовать**: Вопросы о конкретных людях, местах, объектах

---

### **3. Global (Глобальный)**
- **Описание**: Utilizes global knowledge
- **Простыми словами**: Использует глобальные знания
- **Особенности**:
  - В этом режиме параметр `top_k` представляет количество **relationships (связей)**
  - Анализирует связи между сущностями
  - Работает с общими паттернами в данных
- **Когда использовать**: Вопросы о трендах, закономерностях, общих темах

---

### **4. Hybrid (Гибридный)**
- **Описание**: Combines local and global retrieval methods
- **Простыми словами**: Комбинирует локальный и глобальный методы поиска
- **Особенности**:
  - Использует и entities, и relationships
  - Наиболее сбалансированный режим
  - Хороший баланс точности и скорости
- **Когда использовать**: **Рекомендуется по умолчанию** для большинства запросов

---

### **5. Mix (Смешанный)**
- **Описание**: Integrates knowledge graph and vector retrieval
- **Простыми словами**: Интегрирует граф знаний и векторный поиск
- **Особенности**:
  - Комбинирует структурированные данные (граф) с векторным поиском
  - Наиболее полный режим
  - Более ресурсоемкий (медленнее)
- **Когда использовать**: Когда нужна максимальная полнота результатов

---

### **6. Bypass**
- **Описание**: Режим без описания в официальной документации
- **Особенности**: Предположительно пропускает стандартную RAG-обработку
- **Когда использовать**: Специальные случаи (назначение неизвестно)

---

## 🔧 Параметры запроса (QueryParam)

```python
class QueryParam:
    """Configuration parameters for query execution in LightRAG."""

    mode: Literal["local", "global", "hybrid", "naive", "mix", "bypass"] = "global"
    """Режим поиска (см. описание выше)"""

    only_need_context: bool = False
    """Если True, возвращает только извлеченный контекст без генерации ответа"""

    only_need_prompt: bool = False
    """Если True, возвращает только сгенерированный промпт без ответа"""

    response_type: str = "Multiple Paragraphs"
    """Формат ответа: 'Multiple Paragraphs', 'Single Paragraph', 'Bullet Points'"""

    stream: bool = False
    """Если True, включает потоковый вывод для ответов в реальном времени"""

    top_k: int = 60
    """Количество топ элементов для извлечения:
    - В 'local' режиме: количество entities (сущностей)
    - В 'global' режиме: количество relationships (связей)
    """

    chunk_top_k: int = 20
    """Количество текстовых чанков из векторного поиска"""

    max_entity_tokens: int = 6000
    """Максимум токенов для контекста сущностей"""

    max_relation_tokens: int = 8000
    """Максимум токенов для контекста связей"""

    max_total_tokens: int = 30000
    """Максимальный бюджет токенов для всего запроса"""

    conversation_history: list[dict[str, str]] = []
    """История разговора для поддержания контекста
    Формат: [{"role": "user/assistant", "content": "message"}]
    """

    enable_rerank: bool = True
    """Включить ре-ранжирование извлеченных чанков для улучшения релевантности"""

    user_prompt: str | None = None
    """Пользовательский промпт для управления обработкой результатов"""
```

---

## 🌐 Использование в UI

В интерфейсе LightRAG (`https://social.aigain.io:7040`) вы можете выбрать режим из выпадающего списка **Query Mode**:

```
┌─────────────────────────────────┐
│ Query Mode                      │
├─────────────────────────────────┤
│ ✓ Mix                           │
│   Naive                         │
│   Local                         │
│   Global                        │
│   Hybrid                        │
│   Bypass                        │
└─────────────────────────────────┘
```

---

## 💡 Рекомендации по выбору режима

| Режим | Скорость | Точность | Сценарий использования |
|-------|----------|----------|------------------------|
| **Naive** | ⚡⚡⚡⚡⚡ | ⭐⭐ | Быстрый поиск, простые вопросы |
| **Local** | ⚡⚡⚡⚡ | ⭐⭐⭐ | Вопросы о конкретных сущностях |
| **Global** | ⚡⚡⚡⚡ | ⭐⭐⭐ | Вопросы о связях и паттернах |
| **Hybrid** | ⚡⚡⚡ | ⭐⭐⭐⭐ | **Универсальный (рекомендуется)** |
| **Mix** | ⚡⚡ | ⭐⭐⭐⭐⭐ | Максимальная полнота |
| **Bypass** | ⚡⚡⚡⚡⚡ | ❓ | Специальные случаи |

---

## 📊 Конфигурация в проекте

### Настройки из `.env`:

```bash
# LightRAG Authentication
AUTH_ACCOUNTS=admin:xxxxxxxxxxxx
TOKEN_SECRET=xxxxxx

# LightRAG Configuration
SUMMARY_LANGUAGE=English
CHUNK_SIZE=1200
CHUNK_OVERLAP_SIZE=200
FORCE_LLM_SUMMARY_ON_MERGE=4
SUMMARY_MAX_TOKENS=30000

# Embeddings Configuration
EMBEDDING_BINDING=openai
EMBEDDING_MODEL=text-embedding-3-large
EMBEDDING_DIM=3072
EMBEDDING_BINDING_API_KEY=sk-***

# LLM Configuration
LLM_BINDING=openai
LLM_MODEL=gpt-4.1-mini
LLM_BINDING_API_KEY=sk-***

# Performance Settings
MAX_ASYNC=12
MAX_PARALLEL_INSERT=3
EMBEDDING_FUNC_MAX_ASYNC=24
EMBEDDING_BATCH_NUM=100
```

### Доступ к сервису:

**Внешний доступ (из браузера):**
```
https://social.aigain.io:7040           # WebUI и API
https://social.aigain.io:7040/docs      # Swagger документация
https://social.aigain.io:7040/redoc     # ReDoc документация
```

**Внутренний доступ (из других Docker контейнеров):**
```
http://lightrag:9621                    # По имени сервиса
http://service_lightrag:9621            # По имени контейнера
```

---

## 🔍 Примеры использования

### Python API:

```python
from lightrag import LightRAG, QueryParam

# Инициализация
rag = LightRAG(working_dir="./rag_storage")

# Naive поиск
response = rag.query(
    "What are the main topics?",
    param=QueryParam(mode="naive")
)

# Local поиск (контекст вокруг сущностей)
response = rag.query(
    "Tell me about John Smith",
    param=QueryParam(mode="local", top_k=60)
)

# Global поиск (связи и паттерны)
response = rag.query(
    "What are the relationships between characters?",
    param=QueryParam(mode="global", top_k=60)
)

# Hybrid поиск (рекомендуется)
response = rag.query(
    "Summarize the main themes and characters",
    param=QueryParam(mode="hybrid")
)

# Mix поиск (максимальная полнота)
response = rag.query(
    "Comprehensive analysis of the document",
    param=QueryParam(mode="mix", max_total_tokens=30000)
)
```

### REST API:

```bash
# Запрос через API с токеном
curl -X POST https://social.aigain.io:7040/api/query \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What are the main themes?",
    "mode": "hybrid",
    "top_k": 60
  }'
```

---

## 🎯 Дополнительные префиксы для UI

В UI можно использовать специальные префиксы для быстрого выбора режима:

```
/local      - Local режим
/global     - Global режим
/hybrid     - Hybrid режим
/naive      - Naive режим
/mix        - Mix режим
/bypass     - Bypass режим
```

**Пример с пользовательским промптом:**
```
/hybrid[Use mermaid format] Draw a character relationship diagram
/mix[Format as bullet points] Summarize the main themes
```

---

## 📚 Дополнительная информация

- **Документация**: https://github.com/hkuds/lightrag
- **API Docs**: https://social.aigain.io:7040/docs
- **Версия**: latest (ghcr.io/hkuds/lightrag:latest)
- **Порт внутри контейнера**: 9621
- **Внешний HTTPS порт**: 7040

---

## 🔐 Аутентификация

LightRAG использует JWT токены для защиты API. Учетные данные из `.env`:

```bash
# Логин для получения JWT токена
curl -X POST https://social.aigain.io:7040/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "SOC_LightRAG_5674h54worijtorjksdfg"}'

# Ответ:
{"access_token": "eyJ0eXAiOiJKV1QiLCJhb..."}
```

---

**Дата создания**: 2025-10-07
**Версия документа**: 1.0
**Проект**: AI Project v2.5.2