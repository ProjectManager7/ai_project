# LightRAG UltraThink Test Report
**Дата тестирования:** 2025-10-07
**Версия LightRAG:** v1.4.9
**API Version:** 0233

---

## 1. Обзор проекта

### Изученные файлы:
- ✅ [README.md](README.md) - Детальная документация проекта (v2.5 Enhanced Security Edition)
- ✅ [docker-compose.yml](docker-compose.yml) - Конфигурация всех сервисов
- ✅ [.env](.env) - Реальные переменные окружения
- ✅ Документация LightRAG через MCP Context7

### Архитектура:
Проект представляет собой комплексную AI-платформу на базе Docker с следующими сервисами:
- **Traefik** - реверс-прокси с SSL/TLS терминацией
- **Node-RED** - визуальное программирование для автоматизации
- **Flowise AI** - low-code AI workflows
- **LightRAG** - Knowledge Graph & RAG система (фокус тестирования)
- **MySQL** - реляционная БД
- **Redis** - кэширование
- **ChromaDB** - векторная БД
- **Chroma-API** - REST API для ChromaDB
- **Nginx** - статические файлы

---

## 2. Конфигурация LightRAG

### Доступ:
- **Внешний URL:** https://social.aigain.io:7040/webui/
- **Внутренний URL:** http://lightrag:9621 (Docker сеть)
- **API Docs:** https://social.aigain.io:7040/docs

### Авторизация:
- **Тип:** JWT токены (OAuth2PasswordRequestForm)
- **Endpoint логина:** POST /login (form-data)
- **Учетные данные:** admin:SOC_LightRAG_5674h54worijtorjksdfg
- **Формат токена:** Bearer token

### Настройки из .env:
```bash
# LLM Configuration
LLM_BINDING=openai
LLM_MODEL=gpt-4.1-mini
LLM_BINDING_HOST=https://api.openai.com/v1

# Embeddings Configuration
EMBEDDING_BINDING=openai
EMBEDDING_MODEL=text-embedding-3-large
EMBEDDING_DIM=3072

# RAG Configuration
CHUNK_SIZE=1200
CHUNK_OVERLAP_SIZE=200
SUMMARY_LANGUAGE=English
MAX_ASYNC=12
```

### Storage Configuration:
- **KV Storage:** JsonKVStorage
- **Vector Storage:** NanoVectorDBStorage
- **Graph Storage:** NetworkXStorage
- **Document Storage:** JsonDocStatusStorage

### Загруженные данные:
- **Документы:** 1 (RdSAP 10 Specification 10-06-2025.pdf)
- **Граф:** 183 узла, 214 рёбер
- **Чанки:** 6
- **Сущности (entities):** 1 полная запись
- **Связи (relations):** 1 полная запись

---

## 3. Теория: Режимы поиска LightRAG

Согласно официальной документации ([hkuds/lightrag](https://github.com/hkuds/lightrag)):

### 3.1 Доступные режимы:
1. **Naive** - базовый поиск без использования графа
2. **Local** - фокус на контекстно-зависимой информации (entities)
3. **Global** - использует глобальные знания (relationships)
4. **Hybrid** - комбинирует local и global методы
5. **Mix** - интегрирует граф знаний и векторный поиск
6. **Bypass** - специальный режим

### 3.2 Hybrid Mode (Фокус тестирования):

#### Описание из документации:
> **"Hybrid"**: Combines local and global retrieval methods

#### Параметры QueryParam для Hybrid:
```python
class QueryParam:
    mode: Literal["local", "global", "hybrid", "naive", "mix", "bypass"] = "global"

    # top_k для Hybrid режима:
    top_k: int = 60  # В local - entities, в global - relationships

    # Токен-лимиты:
    max_entity_tokens: int = 6000
    max_relation_tokens: int = 8000
    max_total_tokens: int = 30000
```

#### Что делает Hybrid:
- ✅ Извлекает **entities (сущности)** из графа знаний
- ✅ Извлекает **relationships (связи)** между сущностями
- ✅ Комбинирует оба типа данных для построения контекста
- ✅ Использует векторный поиск для чанков текста
- ✅ Применяет LLM для генерации финального ответа

---

## 4. Практическое тестирование Hybrid Mode

### 4.1 Авторизация:

**Запрос:**
```bash
curl -X POST "https://social.aigain.io:7040/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=SOC_LightRAG_5674h54worijtorjksdfg"
```

**Ответ:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "auth_mode": "enabled",
  "core_version": "v1.4.9",
  "api_version": "0233"
}
```
✅ **Результат:** Успешно получен JWT токен

---

### 4.2 Тест запроса с `only_need_context: true`

**Цель:** Получить контекст без генерации ответа, чтобы увидеть что именно извлекается из графа.

**Запрос:**
```bash
curl -X POST "https://social.aigain.io:7040/query" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"query":"What are dwelling types?","mode":"hybrid","only_need_context":true}'
```

**Результат:**

#### Извлечённые Entities (примеры):
```json
{
  "entity": "Park Homes",
  "type": "concept",
  "description": "Park Homes are detached bungalow-style homes..."
}
{
  "entity": "Dwelling Types",
  "type": "content",
  "description": "Dwelling Types is the RdSAP10 classification content..."
}
{
  "entity": "House",
  "type": "concept",
  "description": "House is a dwelling type in RdSAP10..."
}
{
  "entity": "Flat",
  "type": "concept",
  "description": "Flat is a dwelling type in RdSAP10..."
}
```

#### Извлечённые Relationships (примеры):
```json
{
  "entity1": "Dwelling Types",
  "entity2": "Park Home",
  "description": "Dwelling Types includes Park Home as one of the primary dwelling classifications."
}
{
  "entity1": "Dwelling Types",
  "entity2": "House",
  "description": "Dwelling Types includes House as one of the primary dwelling classifications."
}
{
  "entity1": "House",
  "entity2": "Semi-Detached",
  "description": "House may be classified as Semi-Detached under the RdSAP10..."
}
```

✅ **Вывод:** Hybrid режим действительно извлекает **и entities, и relationships** из графа знаний.

---

### 4.3 Сравнение режимов (длина ответа и References)

**Тестовый запрос:** "What is a Park Home?"

| Режим    | Длина ответа | References                                      |
|----------|--------------|------------------------------------------------|
| **naive** | 1478 chars   | [1] RdSAP 10 Specification 10-06-2025.pdf (2).pdf |
| **local** | 2137 chars   | [1] RdSAP 10 Specification 10-06-2025.pdf (2).pdf |
| **global** | 1831 chars   | [1] RdSAP 10 Specification 10-06-2025.pdf (2).pdf |
| **hybrid** | 2186 chars   | [1] RdSAP 10 Specification 10-06-2025.pdf (2).pdf |

✅ **Выводы:**
- Hybrid дает **самый длинный и детальный ответ** (2186 chars)
- Все режимы возвращают **References** с исходным документом
- References указывают на файл, из которого взята информация

---

### 4.4 Детальный анализ Hybrid ответа

**Запрос:** "What is a Park Home according to RdSAP?"

**References:**
```json
[
  {
    "reference_id": "1",
    "file_path": "RdSAP 10 Specification 10-06-2025.pdf (2).pdf"
  }
]
```

**Фрагмент ответа:**
```
According to RdSAP, a Park Home is a type of dwelling classified as a
detached bungalow-style home. These homes are typically manufactured
offsite and then placed on land that is either privately owned or owned
by a local authority. The specification for Park Homes in RdSAP includes
a detailed set of data items applicable specifically to Park Homes, which
covers aspects such as built form, measurements, number of storeys,
extensions, habitable rooms, roof type and insulation, walls, party walls...

### References
* [1] RdSAP 10 Specification 10-06-2025.pdf (2).pdf
```

---

## 5. Источники информации в Hybrid режиме

### Из каких References тянет информацию Hybrid:

#### 1. **Knowledge Graph (Граф знаний):**
- **Entities (Сущности):**
  - Извлекаются специфичные для запроса entities
  - Включают тип, описание, связи
  - Пример: "Park Home", "Dwelling Types", "House", "Flat"

- **Relationships (Связи):**
  - Связи между entities
  - Описание отношений
  - Пример: "Dwelling Types includes Park Home", "House may be classified as Semi-Detached"

#### 2. **Vector Storage (Векторное хранилище):**
- Text chunks (текстовые фрагменты)
- Semantic search результаты
- Chunk top-k = 20 (по умолчанию)

#### 3. **Source Documents:**
- Указаны в секции `references`
- В данном случае: **RdSAP 10 Specification 10-06-2025.pdf (2).pdf**
- Это исходный документ, из которого построен граф знаний

---

## 6. Финальные выводы

### ✅ Hybrid режим работает корректно:

1. **Поиск по графу:**
   - ✅ Извлекает entities (сущности)
   - ✅ Извлекает relationships (связи)
   - ✅ Комбинирует оба типа данных

2. **References:**
   - ✅ Правильно указывает исходный документ
   - ✅ Присутствует в секции `references` ответа
   - ✅ Включает `reference_id` и `file_path`

3. **Качество ответов:**
   - ✅ Hybrid дает самый полный ответ (2186 chars)
   - ✅ Использует информацию из графа знаний
   - ✅ Корректно цитирует источники

4. **Архитектура:**
   - ✅ LightRAG работает в Docker
   - ✅ Доступен через Traefik с SSL
   - ✅ JWT авторизация настроена
   - ✅ Граф загружен (183 узла, 214 рёбер)

---

## 7. Технические детали

### Состояние системы:
```bash
Container: service_lightrag
Status: Up 2 minutes
Graph: 183 nodes, 214 edges
Documents: 1 processed
Chunks: 6
Reranking: Disabled
```

### API Endpoints используемые в тесте:
- `POST /login` - Авторизация
- `POST /query` - Выполнение запросов
- `GET /docs` - API документация

### Конфигурация запросов:
```json
{
  "query": "Your question here",
  "mode": "hybrid",
  "only_need_context": false,
  "top_k": 60,
  "chunk_top_k": 20
}
```

---

## 8. Рекомендации

### Что работает хорошо:
- ✅ Hybrid режим - лучший выбор для большинства запросов
- ✅ References корректно отображаются
- ✅ Граф знаний построен правильно

### Потенциальные улучшения:
- 🔄 Reranking отключен - можно включить для улучшения релевантности
- 🔄 Можно добавить больше документов для расширения knowledge base
- 🔄 Рассмотреть использование Neo4j для больших графов (сейчас NetworkX)

---

## 9. Итоговая оценка

| Критерий | Оценка | Комментарий |
|----------|--------|-------------|
| Hybrid режим работает | ✅ Отлично | Извлекает entities и relationships |
| References корректны | ✅ Отлично | Указывает исходный документ |
| Качество ответов | ✅ Хорошо | Самый полный ответ среди режимов |
| Архитектура | ✅ Отлично | Правильно настроена |
| Документация | ✅ Отлично | Детальная и актуальная |

**Общая оценка: 9.5/10** 🎉

---

*Тест выполнен с использованием Claude Code и официальной документации LightRAG*
