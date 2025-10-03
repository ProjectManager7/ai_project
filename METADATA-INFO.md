# Нативная поддержка метаданных в LightRAG через новый API endpoint

## Проблема

LightRAG имеет встроенную поддержку метаданных на уровне Python API (`insert_custom_kg`, `file_paths`, `source_id`), но стандартные REST API endpoints (`/documents/upload`, `/documents/text`) **не принимают метаданные**.

## Решение: Вариант Б - Новый endpoint `/documents/upload_with_metadata`

### Архитектура решения

```
Файл + Метаданные → Новый endpoint → Парсинг файла → Chunking (встроенный) → insert_custom_kg → LightRAG
                                                                                      ↓
                                                                          Метаданные на каждом чанке
```

### Преимущества подхода

1. ✅ **Нативная поддержка метаданных** - любые поля, без ограничений
2. ✅ **REST API** - совместимость с Node-RED, Flowise, HTTP клиентами
3. ✅ **Встроенный chunking** - используется стандартный `ChunkedTextSplitter` из LightRAG
4. ✅ **Автоматическое извлечение entities** - LLM обрабатывает текст как обычно
5. ✅ **Поддержка любых форматов** - PDF, DOCX, TXT, CSV, JSON (встроенные парсеры)
6. ✅ **Не требует изменения существующих endpoints** - обратная совместимость
7. ✅ **Чистое хранение метаданных** - как отдельные поля в графе знаний

### Отличие от прокси-сервиса

| Критерий | Прокси-сервис | Новый endpoint |
|----------|---------------|----------------|
| **Хранение метаданных** | Встроены в текст | Отдельные поля в БД |
| **Загрязнение контента** | ⚠️ Да | ✅ Нет |
| **Фильтрация по метаданным** | ❌ Сложно | ✅ Прямой доступ |
| **Дополнительные сервисы** | ⚠️ Нужен прокси | ✅ Встроено в LightRAG |
| **Извлечение метаданных** | ⚠️ Парсинг текста | ✅ Прямой доступ к полям |
| **Разработка** | 1-2 дня | 0.5-1 день |

---

## Детальное описание решения

### 1. Поддержка различных форматов файлов

**✅ Да, через встроенные парсеры LightRAG:**

LightRAG API уже поддерживает различные форматы:

```python
SUPPORTED_EXTENSIONS = {
    '.txt', '.md',           # Текстовые файлы
    '.pdf',                  # PDF (PyPDF2, pdfplumber)
    '.docx', '.doc',         # Word (python-docx)
    '.pptx',                 # PowerPoint
    '.csv',                  # CSV (pandas)
    '.json', '.xml'          # Структурированные данные
}
```

**Новый endpoint использует те же парсеры:**

```python
@router.post("/documents/upload_with_metadata")
async def upload_with_metadata(
    file: UploadFile = File(...),
    metadata: str = Form(default="{}")
):
    # 1. Проверка типа файла
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(415, f"Unsupported file type: {file_ext}")

    # 2. Парсинг файла (ВСТРОЕННЫЕ функции LightRAG)
    file_content = await file.read()

    if file_ext == '.pdf':
        text = parse_pdf(file_content)      # встроенная функция
    elif file_ext == '.docx':
        text = parse_docx(file_content)     # встроенная функция
    elif file_ext in ['.txt', '.md']:
        text = file_content.decode('utf-8')
    elif file_ext == '.csv':
        text = parse_csv(file_content)      # встроенная функция
    # ... и т.д.

    # 3. Дальнейшая обработка с метаданными
    ...
```

---

### 2. Произвольные метаданные (не только source_id)

**✅ ЛЮБЫЕ метаданные - нет ограничений!**

LightRAG не имеет жесткой схемы для полей. Все данные хранятся как JSON/Dict.

#### Пример: Полный набор метаданных

```python
custom_kg = {
    "chunks": [{
        "content": "текст документа",

        # Стандартные поля LightRAG
        "source_id": "doc-123",              # ID документа
        "file_path": "/reports/2025/q1.pdf", # Путь к файлу

        # ПРОИЗВОЛЬНЫЕ метаданные - что угодно!
        "author": "Иванов Иван Иванович",
        "department": "Финансовый отдел",
        "date_created": "2025-01-15",
        "date_modified": "2025-01-20",
        "version": "1.2",
        "category": "финансовая отчетность",
        "subcategory": "квартальный отчет",
        "tags": ["Q1", "2025", "важный", "конфиденциально"],
        "confidentiality": "internal",
        "project_id": "PROJ-2025-001",
        "approver": "Петров П.П.",
        "status": "approved",
        "language": "ru",
        "pages": 15,
        "custom_field_1": "любое значение",
        "custom_field_2": {"nested": "структура", "data": [1, 2, 3]},
        "metadata_version": "2.0"
        # ... любые другие поля!
    }]
}
```

#### Как это работает внутри LightRAG

```python
# LightRAG сохраняет данные как есть (упрощенно)
chunk_data = {
    "content": "...",
    "source_id": "...",
    **metadata  # ← Все дополнительные поля сохраняются
}

# В KV Storage (JSON/Redis/PostgreSQL)
await kv_storage.set(chunk_id, chunk_data)

# При чтении получаем все поля обратно
retrieved_chunk = await kv_storage.get(chunk_id)
print(retrieved_chunk["author"])        # "Иванов Иван Иванович"
print(retrieved_chunk["department"])    # "Финансовый отдел"
```

---

### 3. Встроенный механизм chunking и извлечения entities

**✅ Да, используем стандартный pipeline LightRAG**

#### Вариант А: Автоматический chunking БЕЗ метаданных на чанках (простой)

```python
@router.post("/documents/upload_simple")
async def upload_simple(
    file: UploadFile = File(...),
    metadata: str = Form(default="{}")
):
    # Парсим файл
    text = await parse_file(file)
    meta = json.loads(metadata)

    # Добавляем метаданные В НАЧАЛО текста (как блок)
    enriched_text = f"""
[DOCUMENT_METADATA]
{json.dumps(meta, ensure_ascii=False, indent=2)}
[/DOCUMENT_METADATA]

{text}
"""

    # Используем стандартный insert() - автоматический chunking
    await rag.insert(
        enriched_text,
        file_paths=[file.filename],
        ids=[meta.get("source_id")]
    )
```

**Минус:** Метаданные только в первом чанке, остальные чанки их не содержат.

---

#### Вариант Б: Manual chunking + метаданные на КАЖДОМ чанке (рекомендуется)

```python
from lightrag.core.text_splitter import ChunkedTextSplitter
import uuid

@router.post("/documents/upload_with_metadata")
async def upload_with_metadata(
    file: UploadFile = File(...),
    metadata: str = Form(default="{}"),
    chunk_size: int = Form(default=1200),
    chunk_overlap: int = Form(default=200)
):
    """
    Загрузка файла с метаданными

    Args:
        file: Файл (PDF, DOCX, TXT, CSV, JSON, etc.)
        metadata: JSON строка с произвольными метаданными
        chunk_size: Размер чанка в токенах (по умолчанию 1200)
        chunk_overlap: Перекрытие чанков в токенах (по умолчанию 200)

    Returns:
        {
            "track_id": "...",
            "chunks_created": 5,
            "metadata_applied": true
        }
    """

    # 1. Парсим файл в текст (используем ВСТРОЕННЫЕ парсеры)
    text = await parse_file(file)

    # 2. Парсим метаданные
    meta = json.loads(metadata)

    # Генерируем source_id если не указан
    source_id = meta.get("source_id", str(uuid.uuid4()))
    file_path = meta.get("file_path", file.filename)

    # 3. Используем ВСТРОЕННЫЙ chunker из LightRAG
    splitter = ChunkedTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        tokenizer=rag.tokenizer  # Используем tokenizer из LightRAG instance
    )

    chunks = splitter.split_text(text)

    # 4. Создаем custom_kg с метаданными для КАЖДОГО чанка
    custom_kg = {
        "chunks": [
            {
                "content": chunk,
                "source_id": source_id,
                "file_path": file_path,
                "chunk_index": i,              # Номер чанка
                "total_chunks": len(chunks),   # Всего чанков в документе

                # ВСЕ метаданные применяются к каждому чанку
                **{k: v for k, v in meta.items()
                   if k not in ["source_id", "file_path"]}
            }
            for i, chunk in enumerate(chunks)
        ]
    }

    # 5. Вставляем - LightRAG автоматически:
    #    - Извлечет entities через LLM
    #    - Создаст relationships через LLM
    #    - Сохранит метаданные на каждом чанке
    track_id = await rag.insert_custom_kg(custom_kg)

    return {
        "track_id": track_id,
        "chunks_created": len(chunks),
        "metadata_applied": True,
        "source_id": source_id
    }
```

**✅ Что происходит внутри LightRAG после вызова `insert_custom_kg`:**

1. **Chunking уже сделан** - передаем готовые чанки
2. **LLM извлекает entities** из каждого чанка автоматически
3. **LLM создает relationships** между entities автоматически
4. **Векторизация чанков** - embedding модель
5. **Сохранение в storage** - метаданные сохраняются вместе с каждым чанком

**Результат в базе данных:**

```json
// Chunk 1
{
  "chunk_id": "chunk-1",
  "content": "В первом квартале 2025 года...",
  "source_id": "report-q1-2025",
  "file_path": "/reports/q1-2025.pdf",
  "chunk_index": 0,
  "total_chunks": 5,
  "author": "Иванов",
  "department": "финансы",
  "category": "отчетность",
  "date_created": "2025-01-15"
}

// Chunk 2
{
  "chunk_id": "chunk-2",
  "content": "Выручка компании составила...",
  "source_id": "report-q1-2025",  // Тот же source_id
  "file_path": "/reports/q1-2025.pdf",
  "chunk_index": 1,
  "total_chunks": 5,
  "author": "Иванов",              // Метаданные на каждом чанке!
  "department": "финансы",
  "category": "отчетность",
  "date_created": "2025-01-15"
}
```

---

### 4. Работа с метаданными при поиске

#### 4.1 Фильтрация по source_id (встроенная поддержка)

**✅ Работает из коробки:**

```python
# Python API
result = await rag.query(
    "Какие финансовые показатели?",
    param=QueryParam(
        mode="hybrid",
        ids=["report-q1-2025", "report-q2-2025"]  # Фильтр по source_id
    )
)
```

**REST API:**

```bash
curl -X POST "http://localhost:9621/query" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "финансовые показатели",
    "mode": "hybrid",
    "ids": ["report-q1-2025", "report-q2-2025"]
  }'
```

---

#### 4.2 Фильтрация по произвольным метаданным (требует новый endpoint)

**Новый endpoint: `/query_with_filter`**

```python
@router.post("/query_with_filter")
async def query_with_filter(
    query: str,
    metadata_filter: dict = {},  # Фильтры по метаданным
    mode: str = "hybrid",
    include_metadata: bool = True
):
    """
    Поиск с фильтрацией по произвольным метаданным

    Args:
        query: Поисковый запрос
        metadata_filter: Фильтры, например:
            {
                "department": "финансы",
                "category": "отчетность",
                "date_created": "2025-01-15"
            }
        mode: Режим поиска (local/global/hybrid/mix)
        include_metadata: Включить метаданные в ответ

    Returns:
        Результат поиска с отфильтрованными по метаданным документами
    """

    # 1. Получаем все чанки из KV Storage
    all_chunks = await rag.kv_storage.get_all_chunks()

    # 2. Фильтруем по метаданным
    filtered_source_ids = set()

    for chunk_id, chunk_data in all_chunks.items():
        # Проверяем соответствие ВСЕМ фильтрам
        match = all(
            chunk_data.get(key) == value
            for key, value in metadata_filter.items()
        )

        if match:
            filtered_source_ids.add(chunk_data.get("source_id"))

    # 3. Если нет совпадений - возвращаем пустой результат
    if not filtered_source_ids:
        return {
            "answer": "Документы с указанными метаданными не найдены.",
            "filtered_documents": 0,
            "sources": []
        }

    # 4. Делаем запрос только по отфильтрованным документам
    result = await rag.query(
        query,
        param=QueryParam(
            mode=mode,
            ids=list(filtered_source_ids)  # Только отфильтрованные
        )
    )

    # 5. Опционально: добавляем метаданные в ответ
    if include_metadata:
        result.chunks_with_metadata = await _enrich_with_metadata(
            result.source_chunks
        )

    result.filtered_documents = len(filtered_source_ids)

    return result


async def _enrich_with_metadata(chunk_ids: list[str]) -> list[dict]:
    """Добавляет метаданные к чанкам в результатах"""
    chunks_with_meta = []

    for chunk_id in chunk_ids:
        chunk_data = await rag.kv_storage.get(chunk_id)

        chunks_with_meta.append({
            "content": chunk_data["content"],
            "metadata": {
                k: v for k, v in chunk_data.items()
                if k not in ["content", "embedding"]  # Все кроме контента и векторов
            }
        })

    return chunks_with_meta
```

**Использование:**

```bash
# Поиск с фильтрацией по нескольким метаданным
curl -X POST "http://localhost:9621/query_with_filter" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "квартальные показатели выручки",
    "metadata_filter": {
      "department": "финансы",
      "category": "отчетность",
      "author": "Иванов"
    },
    "mode": "hybrid",
    "include_metadata": true
  }'
```

**Результат:**

```json
{
  "answer": "Квартальные показатели выручки за Q1 2025 составили 150 млн руб...",
  "filtered_documents": 3,
  "chunks_with_metadata": [
    {
      "content": "В первом квартале 2025 года выручка составила 150 млн руб...",
      "metadata": {
        "source_id": "report-q1-2025",
        "file_path": "/reports/q1-2025.pdf",
        "chunk_index": 0,
        "total_chunks": 5,
        "author": "Иванов",
        "department": "финансы",
        "category": "отчетность",
        "date_created": "2025-01-15",
        "tags": ["Q1", "2025", "важный"]
      }
    },
    {
      "content": "Операционная прибыль увеличилась на 20%...",
      "metadata": {
        "source_id": "report-q1-2025",
        "file_path": "/reports/q1-2025.pdf",
        "chunk_index": 2,
        "total_chunks": 5,
        "author": "Иванов",
        "department": "финансы",
        "category": "отчетность",
        "date_created": "2025-01-15",
        "tags": ["Q1", "2025", "важный"]
      }
    }
  ],
  "sources": [
    {
      "source_id": "report-q1-2025",
      "file_path": "/reports/q1-2025.pdf",
      "relevance_score": 0.95
    }
  ]
}
```

---

#### 4.3 Сложные фильтры (диапазоны, списки, регулярные выражения)

**Расширенная фильтрация:**

```python
@router.post("/query_advanced_filter")
async def query_advanced_filter(
    query: str,
    filters: dict = {}
):
    """
    Расширенная фильтрация с поддержкой операторов

    Примеры фильтров:
    {
        "department": {"$eq": "финансы"},           # Равно
        "date_created": {"$gte": "2025-01-01"},     # Больше или равно
        "tags": {"$contains": "важный"},            # Содержит элемент
        "author": {"$in": ["Иванов", "Петров"]},    # В списке
        "category": {"$regex": "отчет.*"}           # Регулярное выражение
    }
    """

    all_chunks = await rag.kv_storage.get_all_chunks()
    filtered_source_ids = set()

    for chunk_id, chunk_data in all_chunks.items():
        match = True

        for field, condition in filters.items():
            if isinstance(condition, dict):
                # Операторы
                if "$eq" in condition:
                    match &= chunk_data.get(field) == condition["$eq"]
                elif "$gte" in condition:
                    match &= chunk_data.get(field, "") >= condition["$gte"]
                elif "$lte" in condition:
                    match &= chunk_data.get(field, "") <= condition["$lte"]
                elif "$contains" in condition:
                    match &= condition["$contains"] in chunk_data.get(field, [])
                elif "$in" in condition:
                    match &= chunk_data.get(field) in condition["$in"]
                elif "$regex" in condition:
                    import re
                    pattern = re.compile(condition["$regex"])
                    match &= bool(pattern.match(str(chunk_data.get(field, ""))))
            else:
                # Простое равенство
                match &= chunk_data.get(field) == condition

        if match:
            filtered_source_ids.add(chunk_data.get("source_id"))

    # Поиск по отфильтрованным документам
    result = await rag.query(
        query,
        param=QueryParam(ids=list(filtered_source_ids))
    )

    return result
```

**Использование:**

```bash
curl -X POST "http://localhost:9621/query_advanced_filter" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "финансовые показатели",
    "filters": {
      "department": {"$eq": "финансы"},
      "date_created": {"$gte": "2025-01-01"},
      "tags": {"$contains": "важный"},
      "author": {"$in": ["Иванов", "Петров"]}
    }
  }'
```

---

## Полная реализация

### Структура файлов

```
lightrag/api/
├── routes/
│   ├── documents.py              # Существующий файл
│   └── documents_metadata.py     # НОВЫЙ файл
├── utils/
│   └── file_parsers.py          # Вспомогательные функции парсинга
└── main.py                       # Регистрация новых роутов
```

### Код: `lightrag/api/routes/documents_metadata.py`

```python
"""
Новые endpoints для работы с метаданными документов
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from pathlib import Path
import json
import uuid
from datetime import datetime

from lightrag.core.text_splitter import ChunkedTextSplitter
from lightrag.core.base import QueryParam
from ..utils.file_parsers import parse_file

router = APIRouter(prefix="/documents", tags=["documents-metadata"])

# Получаем глобальный LightRAG instance
from ..main import get_rag_instance
rag = get_rag_instance()


class MetadataFilter(BaseModel):
    """Модель для фильтрации по метаданным"""
    field: str
    operator: str = "eq"  # eq, gte, lte, contains, in, regex
    value: Any


class QueryWithFilterRequest(BaseModel):
    """Запрос с фильтрацией по метаданным"""
    query: str
    metadata_filter: Optional[Dict[str, Any]] = {}
    mode: str = "hybrid"
    include_metadata: bool = True
    top_k: int = 60


@router.post("/upload_with_metadata")
async def upload_with_metadata(
    file: UploadFile = File(...),
    metadata: str = Form(default="{}"),
    chunk_size: int = Form(default=1200),
    chunk_overlap: int = Form(default=200)
):
    """
    Загрузка файла с произвольными метаданными

    Поддерживаемые форматы: PDF, DOCX, TXT, MD, CSV, JSON, XML

    Args:
        file: Файл для загрузки
        metadata: JSON строка с метаданными, например:
            {
                "source_id": "doc-123",        // опционально
                "file_path": "/path/to/file",  // опционально
                "author": "Иванов И.И.",
                "department": "финансы",
                "date_created": "2025-01-15",
                "category": "отчетность",
                "tags": ["Q1", "важный"],
                ... любые другие поля
            }
        chunk_size: Размер чанка в токенах
        chunk_overlap: Перекрытие чанков в токенах

    Returns:
        {
            "track_id": "...",
            "source_id": "...",
            "chunks_created": 5,
            "metadata_applied": true
        }
    """

    try:
        # 1. Парсим метаданные
        try:
            meta = json.loads(metadata)
        except json.JSONDecodeError:
            raise HTTPException(400, "Invalid JSON in metadata field")

        # 2. Генерируем source_id если не указан
        source_id = meta.get("source_id", f"doc-{uuid.uuid4()}")
        file_path = meta.get("file_path", file.filename)

        # 3. Парсим файл (используем встроенные парсеры)
        text = await parse_file(file)

        # 4. Chunking (используем встроенный splitter)
        splitter = ChunkedTextSplitter(
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            tokenizer=rag.tokenizer
        )

        chunks = splitter.split_text(text)

        # 5. Создаем custom_kg с метаданными на каждом чанке
        custom_kg = {
            "chunks": [
                {
                    "content": chunk,
                    "source_id": source_id,
                    "file_path": file_path,
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                    "indexed_at": datetime.utcnow().isoformat(),

                    # Все метаданные из запроса
                    **{k: v for k, v in meta.items()
                       if k not in ["source_id", "file_path"]}
                }
                for i, chunk in enumerate(chunks)
            ]
        }

        # 6. Вставляем через insert_custom_kg
        # LightRAG автоматически извлечет entities и relationships
        track_id = await rag.ainsert_custom_kg(custom_kg)

        return {
            "track_id": track_id,
            "source_id": source_id,
            "chunks_created": len(chunks),
            "metadata_applied": True,
            "filename": file.filename
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"Processing error: {str(e)}")


@router.post("/query_with_filter")
async def query_with_filter(request: QueryWithFilterRequest):
    """
    Поиск с фильтрацией по метаданным

    Example:
        {
            "query": "квартальные показатели",
            "metadata_filter": {
                "department": "финансы",
                "category": "отчетность",
                "author": "Иванов"
            },
            "mode": "hybrid",
            "include_metadata": true
        }
    """

    try:
        # 1. Получаем все чанки
        all_chunks = await rag.kv_storage.get_all_chunks()

        # 2. Фильтруем по метаданным
        filtered_source_ids = set()

        for chunk_id, chunk_data in all_chunks.items():
            # Проверяем соответствие всем фильтрам
            match = all(
                chunk_data.get(key) == value
                for key, value in request.metadata_filter.items()
            )

            if match:
                filtered_source_ids.add(chunk_data.get("source_id"))

        # 3. Если нет совпадений
        if not filtered_source_ids:
            return {
                "answer": "Документы с указанными метаданными не найдены.",
                "filtered_documents": 0,
                "sources": []
            }

        # 4. Поиск по отфильтрованным документам
        result = await rag.aquery(
            request.query,
            param=QueryParam(
                mode=request.mode,
                ids=list(filtered_source_ids),
                top_k=request.top_k
            )
        )

        # 5. Добавляем метаданные в ответ
        if request.include_metadata:
            chunks_with_meta = []

            for chunk_id in result.get("source_chunks", []):
                chunk_data = await rag.kv_storage.get(chunk_id)

                chunks_with_meta.append({
                    "content": chunk_data["content"],
                    "metadata": {
                        k: v for k, v in chunk_data.items()
                        if k not in ["content", "embedding"]
                    }
                })

            result["chunks_with_metadata"] = chunks_with_meta

        result["filtered_documents"] = len(filtered_source_ids)

        return result

    except Exception as e:
        raise HTTPException(500, f"Query error: {str(e)}")


@router.get("/metadata/fields")
async def get_metadata_fields():
    """
    Получить список всех уникальных полей метаданных в базе

    Returns:
        {
            "fields": ["author", "department", "category", ...],
            "field_values": {
                "department": ["финансы", "IT", "HR"],
                "category": ["отчетность", "инструкции"]
            }
        }
    """

    all_chunks = await rag.kv_storage.get_all_chunks()

    fields = set()
    field_values = {}

    for chunk_data in all_chunks.values():
        for key, value in chunk_data.items():
            if key not in ["content", "embedding", "chunk_index", "total_chunks"]:
                fields.add(key)

                # Собираем уникальные значения
                if key not in field_values:
                    field_values[key] = set()

                if isinstance(value, (str, int, float, bool)):
                    field_values[key].add(str(value))
                elif isinstance(value, list):
                    field_values[key].update(str(v) for v in value)

    return {
        "fields": sorted(list(fields)),
        "field_values": {
            k: sorted(list(v)) for k, v in field_values.items()
        }
    }


@router.get("/metadata/stats")
async def get_metadata_stats():
    """
    Статистика по метаданным в базе

    Returns:
        {
            "total_documents": 150,
            "total_chunks": 750,
            "metadata_coverage": {
                "author": 0.95,      // 95% документов имеют поле author
                "department": 0.80,
                ...
            }
        }
    """

    all_chunks = await rag.kv_storage.get_all_chunks()
    total_chunks = len(all_chunks)

    # Подсчет source_id (уникальных документов)
    source_ids = set(
        chunk.get("source_id")
        for chunk in all_chunks.values()
    )
    total_documents = len(source_ids)

    # Подсчет покрытия метаданных
    field_counts = {}

    for chunk_data in all_chunks.values():
        for key in chunk_data.keys():
            if key not in ["content", "embedding"]:
                field_counts[key] = field_counts.get(key, 0) + 1

    metadata_coverage = {
        field: count / total_chunks
        for field, count in field_counts.items()
    }

    return {
        "total_documents": total_documents,
        "total_chunks": total_chunks,
        "metadata_coverage": metadata_coverage,
        "avg_chunks_per_document": total_chunks / total_documents if total_documents > 0 else 0
    }
```

### Код: `lightrag/api/utils/file_parsers.py`

```python
"""
Вспомогательные функции для парсинга различных форматов файлов
"""

from fastapi import UploadFile, HTTPException
from pathlib import Path
import io

# Импорты парсеров
try:
    import PyPDF2
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False

try:
    from docx import Document
    DOCX_SUPPORT = True
except ImportError:
    DOCX_SUPPORT = False

try:
    import pandas as pd
    CSV_SUPPORT = True
except ImportError:
    CSV_SUPPORT = False


SUPPORTED_EXTENSIONS = {
    '.txt', '.md', '.pdf', '.docx', '.doc',
    '.csv', '.json', '.xml'
}


async def parse_file(file: UploadFile) -> str:
    """
    Парсит файл в текст, используя встроенные парсеры LightRAG

    Args:
        file: Загруженный файл

    Returns:
        str: Текстовое содержимое файла

    Raises:
        HTTPException: Если формат не поддерживается
    """

    file_ext = Path(file.filename).suffix.lower()

    if file_ext not in SUPPORTED_EXTENSIONS:
        raise HTTPException(
            415,
            f"Unsupported file type: {file_ext}. "
            f"Supported: {', '.join(SUPPORTED_EXTENSIONS)}"
        )

    file_content = await file.read()

    # PDF
    if file_ext == '.pdf':
        if not PDF_SUPPORT:
            raise HTTPException(500, "PDF support not installed. Install PyPDF2")
        return _parse_pdf(file_content)

    # DOCX
    elif file_ext == '.docx':
        if not DOCX_SUPPORT:
            raise HTTPException(500, "DOCX support not installed. Install python-docx")
        return _parse_docx(file_content)

    # CSV
    elif file_ext == '.csv':
        if not CSV_SUPPORT:
            raise HTTPException(500, "CSV support not installed. Install pandas")
        return _parse_csv(file_content)

    # JSON
    elif file_ext == '.json':
        return _parse_json(file_content)

    # XML
    elif file_ext == '.xml':
        return _parse_xml(file_content)

    # Plain text
    elif file_ext in ['.txt', '.md']:
        return _parse_text(file_content)

    else:
        # Попытка как текст
        return _parse_text(file_content)


def _parse_pdf(content: bytes) -> str:
    """Извлекает текст из PDF"""
    pdf_file = io.BytesIO(content)
    reader = PyPDF2.PdfReader(pdf_file)

    text_parts = []
    for page_num, page in enumerate(reader.pages, 1):
        text = page.extract_text()
        text_parts.append(f"--- Страница {page_num} ---\n{text}\n")

    return "\n".join(text_parts)


def _parse_docx(content: bytes) -> str:
    """Извлекает текст из DOCX"""
    doc_file = io.BytesIO(content)
    doc = Document(doc_file)

    text_parts = []

    # Параграфы
    for para in doc.paragraphs:
        if para.text.strip():
            text_parts.append(para.text)

    # Таблицы
    for table in doc.tables:
        for row in table.rows:
            row_text = " | ".join(cell.text for cell in row.cells)
            text_parts.append(row_text)

    return "\n\n".join(text_parts)


def _parse_csv(content: bytes) -> str:
    """Извлекает данные из CSV"""
    try:
        df = pd.read_csv(io.BytesIO(content))
        return df.to_string()
    except Exception as e:
        raise HTTPException(400, f"Failed to parse CSV: {str(e)}")


def _parse_json(content: bytes) -> str:
    """Форматирует JSON в текст"""
    import json

    try:
        data = json.loads(content.decode('utf-8'))
        return json.dumps(data, ensure_ascii=False, indent=2)
    except json.JSONDecodeError as e:
        raise HTTPException(400, f"Invalid JSON: {str(e)}")


def _parse_xml(content: bytes) -> str:
    """Парсит XML"""
    import xml.etree.ElementTree as ET

    try:
        root = ET.fromstring(content.decode('utf-8'))
        return ET.tostring(root, encoding='unicode', method='text')
    except ET.ParseError as e:
        raise HTTPException(400, f"Invalid XML: {str(e)}")


def _parse_text(content: bytes) -> str:
    """Парсит текстовые файлы"""
    for encoding in ['utf-8', 'latin-1', 'cp1251']:
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue

    raise HTTPException(400, "Unable to decode file with supported encodings")
```

### Регистрация в `lightrag/api/main.py`

```python
from fastapi import FastAPI
from .routes import documents, documents_metadata

app = FastAPI()

# Существующие роуты
app.include_router(documents.router)

# НОВЫЕ роуты для метаданных
app.include_router(documents_metadata.router)
```

---

## Примеры использования

### 1. Загрузка PDF с метаданными

```bash
curl -X POST "http://localhost:9621/documents/upload_with_metadata" \
  -F "file=@/path/to/quarterly_report_q1_2025.pdf" \
  -F 'metadata={
    "source_id": "report-q1-2025",
    "author": "Иванов Иван Иванович",
    "department": "Финансовый отдел",
    "date_created": "2025-01-15",
    "category": "финансовая отчетность",
    "subcategory": "квартальный отчет",
    "tags": ["Q1", "2025", "важный", "конфиденциально"],
    "confidentiality": "internal",
    "approver": "Петров П.П.",
    "status": "approved"
  }' \
  -F "chunk_size=1200" \
  -F "chunk_overlap=200"
```

**Ответ:**

```json
{
  "track_id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "source_id": "report-q1-2025",
  "chunks_created": 12,
  "metadata_applied": true,
  "filename": "quarterly_report_q1_2025.pdf"
}
```

### 2. Поиск с фильтрацией по метаданным

```bash
curl -X POST "http://localhost:9621/documents/query_with_filter" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "какова выручка компании?",
    "metadata_filter": {
      "department": "Финансовый отдел",
      "category": "финансовая отчетность",
      "status": "approved"
    },
    "mode": "hybrid",
    "include_metadata": true
  }'
```

**Ответ:**

```json
{
  "answer": "Выручка компании в Q1 2025 составила 150 млн рублей, что на 20% выше показателей предыдущего квартала...",
  "filtered_documents": 2,
  "chunks_with_metadata": [
    {
      "content": "В первом квартале 2025 года выручка компании составила 150 млн рублей...",
      "metadata": {
        "source_id": "report-q1-2025",
        "file_path": "quarterly_report_q1_2025.pdf",
        "chunk_index": 3,
        "total_chunks": 12,
        "author": "Иванов Иван Иванович",
        "department": "Финансовый отдел",
        "date_created": "2025-01-15",
        "category": "финансовая отчетность",
        "tags": ["Q1", "2025", "важный"],
        "status": "approved"
      }
    }
  ],
  "sources": [
    {
      "source_id": "report-q1-2025",
      "relevance_score": 0.95
    }
  ]
}
```

### 3. Получение списка метаданных

```bash
curl "http://localhost:9621/documents/metadata/fields"
```

**Ответ:**

```json
{
  "fields": [
    "author",
    "category",
    "date_created",
    "department",
    "source_id",
    "status",
    "tags"
  ],
  "field_values": {
    "department": ["IT", "Финансовый отдел", "HR"],
    "category": ["финансовая отчетность", "инструкции", "политики"],
    "status": ["approved", "draft", "review"]
  }
}
```

### 4. Node-RED интеграция

```javascript
// Node-RED Function node

// Чтение файла из предыдущей ноды
const fileBuffer = msg.payload;

// Формирование метаданных
const metadata = {
    source_id: msg.documentId || `doc-${Date.now()}`,
    author: msg.author || "System",
    department: msg.department || "General",
    date_created: new Date().toISOString().split('T')[0],
    category: msg.category || "general",
    tags: msg.tags || [],
    custom_field: msg.customData
};

// Формирование multipart/form-data
const FormData = require('form-data');
const form = new FormData();

form.append('file', fileBuffer, msg.filename);
form.append('metadata', JSON.stringify(metadata));
form.append('chunk_size', 1200);
form.append('chunk_overlap', 200);

msg.payload = form;
msg.headers = form.getHeaders();
msg.url = 'http://lightrag:9621/documents/upload_with_metadata';
msg.method = 'POST';

return msg;
```

---

## Итоговая сводка

| Вопрос | Ответ |
|--------|-------|
| **Разные форматы файлов?** | ✅ Да: PDF, DOCX, TXT, CSV, JSON, XML (встроенные парсеры LightRAG) |
| **Любые метаданные?** | ✅ Да: любые поля, нет схемы, полная гибкость |
| **Встроенный chunking?** | ✅ Да: `ChunkedTextSplitter` из LightRAG с tokenizer |
| **Автоматическое извлечение entities?** | ✅ Да: через `insert_custom_kg` → LLM обрабатывает текст |
| **Поиск по source_id?** | ✅ Да: встроенная поддержка через параметр `ids` |
| **Поиск по произвольным метаданным?** | ✅ Да: через новый endpoint `/query_with_filter` |
| **Метаданные в результатах?** | ✅ Да: `include_metadata=true` |
| **REST API?** | ✅ Да: полная поддержка через FastAPI |
| **Обратная совместимость?** | ✅ Да: существующие endpoints не затронуты |
| **Разработка?** | 🕐 0.5-1 день (3 файла: роут, парсеры, регистрация) |

---

## Преимущества перед прокси-сервисом

1. ✅ **Чистое хранение** - метаданные как отдельные поля, не в тексте
2. ✅ **Прямой доступ** - фильтрация по любым полям без парсинга
3. ✅ **Встроено в LightRAG** - не нужен дополнительный сервис
4. ✅ **Меньше кода** - используем готовые механизмы LightRAG
5. ✅ **Проще поддержка** - один сервис вместо двух
6. ✅ **Можно сделать PR** - полезно для всего сообщества LightRAG

## Следующие шаги

1. Форкнуть репозиторий LightRAG
2. Создать ветку `feature/metadata-endpoints`
3. Добавить файлы:
   - `lightrag/api/routes/documents_metadata.py`
   - `lightrag/api/utils/file_parsers.py`
4. Обновить `lightrag/api/main.py`
5. Добавить тесты
6. Создать Pull Request в основной репозиторий

Готов помочь с реализацией или тестированием!
