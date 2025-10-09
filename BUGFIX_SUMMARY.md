# 🔧 Отчёт об исправлении ошибки в LightRAG

**Дата:** 2025-10-09
**Компонент:** LightRAG Document Management
**Endpoint:** `/documents/paginated`

---

## 📊 Анализ проекта

### 1. Структура проекта изучена:
- ✅ [README.md](/root/ai_project/README.md) - полная архитектура системы
- ✅ [.env](/root/ai_project/.env) - конфигурация с API ключами и аутентификацией
- ✅ [docker-compose.yml](/root/ai_project/docker-compose.yml) - оркестрация 10+ сервисов

### 2. Документация LightRAG изучена:
- ✅ Официальная документация из GitHub (hkuds/lightrag)
- ✅ API endpoints для работы с документами
- ✅ Модели данных (Pydantic)
- ✅ Методы аутентификации (JWT + API Key)

---

## 🐛 Описание проблемы

**Симптом:**
```
Failed to load documents 500
{"detail":"1 validation error for DocStatusResponse\nfile_path\n
Input should be a valid string [type=string_type, input_value=None, input_type=NoneType]"}
```

**Endpoint:** `POST /documents/paginated`

**Когда возникает:**
При загрузке списка документов в веб-интерфейсе

---

## 🔍 Анализ причины

### Шаг 1: Изучение логов контейнера
```bash
docker logs service_lightrag --tail 100
```

**Найдено:**
- Ошибка возникает в файле `/app/lightrag/api/routers/document_routes.py:2593`
- При создании объекта `DocStatusResponse` передаётся `file_path=None`

### Шаг 2: Анализ хранилища данных
```bash
docker exec service_lightrag cat /app/data/rag_storage/kv_store_doc_status.json
```

**Найдено:**
```json
{
  "doc-63d8db782f599abcbd51aada7ba5421c": {
    "status": "processed",
    "file_path": null,  // ← Проблема здесь!
    "track_id": "insert_20251009_120318_43ad2339",
    ...
  }
}
```

**Причина:**
Документы, вставленные через `/documents/text` API, не имеют файла, поэтому `file_path` сохраняется как `null`.

### Шаг 3: Анализ модели данных
```python
class DocStatusResponse(BaseModel):
    ...
    file_path: str = Field(description="Path to the document file")  # ← Обязательное поле!
```

**Корневая причина:**
Модель Pydantic определяет `file_path` как **обязательную строку**, но в БД могут быть значения `null`.

---

## ✅ Решение

### Исправление модели данных
**Файл:** `lightrag/api/routers/document_routes.py:374`

**Было:**
```python
file_path: str = Field(description="Path to the document file")
```

**Стало:**
```python
file_path: Optional[str] = Field(
    default=None, description="Path to the document file"
)
```

### Применение патча

1. **Извлечение файла из контейнера:**
```bash
mkdir -p /root/ai_project/lightrag/patches
docker exec service_lightrag cat /app/lightrag/api/routers/document_routes.py \
  > /root/ai_project/lightrag/patches/document_routes.py
```

2. **Применение исправления:**
Редактирование строки 374 для добавления `Optional[str]` с `default=None`

3. **Монтирование патча в docker-compose.yml:**
```yaml
lightrag:
  volumes:
    - ./lightrag/patches/document_routes.py:/app/lightrag/api/routers/document_routes.py:ro
```

4. **Пересоздание контейнера:**
```bash
docker compose up -d --force-recreate lightrag
```

---

## ✅ Тестирование

### Проверка применения патча:
```bash
docker exec service_lightrag cat /app/lightrag/api/routers/document_routes.py | sed -n '374,376p'
```

**Результат:**
```python
file_path: Optional[str] = Field(
    default=None, description="Path to the document file"
)
```

### Тестовый запрос:
```bash
curl -X POST "https://social.aigain.io:7040/documents/paginated" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: SOC_LightRAG_API_934kf9cmv349vme39v" \
  -d '{"page": 1, "page_size": 10}' -k
```

### ✅ Успешный ответ:
```json
{
  "documents": [
    {
      "id": "doc-63d8db782f599abcbd51aada7ba5421c",
      "file_path": null,  // ← Теперь работает!
      "status": "processed",
      ...
    },
    {
      "id": "doc-db01404011b635903c257b90eb501072",
      "file_path": "RdSAP 10 Specification 10-06-2025.pdf (2).pdf",
      "status": "processed",
      ...
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 10,
    "total_count": 2,
    "total_pages": 1
  },
  "status_counts": {
    "processed": 2,
    "all": 2
  }
}
```

---

## 📝 Выводы

1. ✅ **Ошибка исправлена:** Endpoint `/documents/paginated` теперь корректно обрабатывает документы с `file_path=null`

2. ✅ **Патч применён:** Создан механизм volume mount для переопределения файлов в контейнере

3. ✅ **Документация создана:** [lightrag/patches/README.md](/root/ai_project/lightrag/patches/README.md)

4. 🔄 **Рекомендация:** Создать Pull Request в официальный репозиторий LightRAG (https://github.com/hkuds/lightrag)

---

## 🎯 Дополнительные наблюдения

### Архитектура проекта:
- **10+ сервисов** в Docker Compose
- **Traefik** как reverse proxy с SSL (Let's Encrypt)
- **LightRAG** на порту 7040 (HTTPS через Traefik)
- **Аутентификация:** JWT + API Key
- **Хранилище:** JSON-based KV store + векторная БД

### Структура данных LightRAG:
- `kv_store_doc_status.json` - статусы документов
- `kv_store_full_docs.json` - полные тексты
- `kv_store_text_chunks.json` - чанки для RAG
- `graph_chunk_entity_relation.graphml` - граф знаний (185 узлов, 215 рёбер)

### Режимы работы LightRAG:
- **naive** - простой поиск
- **local** - контекстный поиск (entities)
- **global** - глобальный поиск (relationships)
- **hybrid** - комбинированный (рекомендуется)
- **mix** - смешанный режим
- **graph** - графовый поиск

---

**Автор:** AI Assistant (Claude Sonnet 4.5)
**Инструменты:** Docker, Python, Pydantic, curl, bash
