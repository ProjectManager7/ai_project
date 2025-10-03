# Решение проблемы метаданных в LightRAG: Промежуточный прокси-сервис

## Проблема

LightRAG API не поддерживает добавление произвольных метаданных при загрузке файлов через REST API endpoints:
- `/documents/upload` - принимает только файл
- `/documents/text` - принимает только текст
- Нет возможности передать дополнительную информацию (автор, дата, категория, теги и т.д.)

## Решение: Прокси-сервис для обогащения метаданными

### Архитектура

```
┌─────────────────┐      ┌──────────────────────┐      ┌─────────────────┐
│   Node-RED      │      │  Прокси-сервис       │      │   LightRAG      │
│   Flowise       │─────▶│  (FastAPI/Flask)     │─────▶│   API Server    │
│   HTTP Client   │      │  Port: 9622          │      │   Port: 9621    │
└─────────────────┘      └──────────────────────┘      └─────────────────┘
                               │
                               │ Обработка:
                               ├─ Парсинг метаданных
                               ├─ Обогащение текста
                               ├─ Форматирование
                               └─ Валидация
```

### Основной функционал

#### 1. Endpoint для загрузки файлов с метаданными

```http
POST /api/upload_with_metadata
Content-Type: multipart/form-data

{
  "file": <binary data>,
  "metadata": {
    "author": "Иванов И.И.",
    "date": "2025-01-15",
    "category": "техническая документация",
    "department": "IT",
    "version": "1.2",
    "tags": ["инструкция", "безопасность"]
  }
}
```

**Ответ:**
```json
{
  "track_id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "status": "processing",
  "metadata_applied": true
}
```

#### 2. Endpoint для загрузки текста с метаданными

```http
POST /api/text_with_metadata
Content-Type: application/json

{
  "content": "Текст документа...",
  "metadata": {
    "source": "email",
    "sender": "admin@example.com",
    "date": "2025-01-15T10:30:00Z"
  }
}
```

### Стратегии обогащения метаданными

#### Стратегия 1: Префикс-блок (рекомендуется)

```python
enriched_text = f"""
[DOCUMENT_METADATA]
Автор: {metadata.get('author', 'Неизвестно')}
Дата создания: {metadata.get('date', 'Неизвестно')}
Категория: {metadata.get('category', 'Общая')}
Отдел: {metadata.get('department', 'Неизвестно')}
Версия: {metadata.get('version', '1.0')}
Теги: {', '.join(metadata.get('tags', []))}
[/DOCUMENT_METADATA]

{original_text}
"""
```

**Преимущества:**
- Структурированный формат
- Легко парсится при поиске
- Не смешивается с основным контентом
- LLM четко видит границы метаданных

#### Стратегия 2: JSON в начале документа

```python
enriched_text = f"""
```metadata
{json.dumps(metadata, ensure_ascii=False, indent=2)}
```

{original_text}
"""
```

**Преимущества:**
- Машиночитаемый формат
- Сохраняет типы данных
- Легко извлечь программно

#### Стратегия 3: Встраивание в контекст

```python
enriched_text = f"""
Это документ от автора {metadata['author']}, созданный {metadata['date']}.
Категория: {metadata['category']}.

{original_text}
"""
```

**Преимущества:**
- Естественный язык
- Лучше для RAG запросов
- LLM понимает контекст

### Пример реализации (FastAPI)

```python
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
import httpx
import json
from typing import Optional, Dict, Any
from datetime import datetime

app = FastAPI(title="LightRAG Metadata Proxy")

# Конфигурация
LIGHTRAG_API_URL = "http://lightrag:9621"
LIGHTRAG_API_KEY = "your-api-key"  # из .env

class MetadataModel(BaseModel):
    author: Optional[str] = None
    date: Optional[str] = None
    category: Optional[str] = None
    department: Optional[str] = None
    version: Optional[str] = None
    tags: Optional[list[str]] = []
    source: Optional[str] = None
    custom: Optional[Dict[str, Any]] = {}

class TextWithMetadata(BaseModel):
    content: str
    metadata: MetadataModel

def enrich_content_with_metadata(content: str, metadata: MetadataModel) -> str:
    """Обогащает контент метаданными"""

    # Формируем блок метаданных
    metadata_lines = ["[DOCUMENT_METADATA]"]

    if metadata.author:
        metadata_lines.append(f"Автор: {metadata.author}")
    if metadata.date:
        metadata_lines.append(f"Дата: {metadata.date}")
    if metadata.category:
        metadata_lines.append(f"Категория: {metadata.category}")
    if metadata.department:
        metadata_lines.append(f"Отдел: {metadata.department}")
    if metadata.version:
        metadata_lines.append(f"Версия: {metadata.version}")
    if metadata.tags:
        metadata_lines.append(f"Теги: {', '.join(metadata.tags)}")
    if metadata.source:
        metadata_lines.append(f"Источник: {metadata.source}")

    # Добавляем custom поля
    if metadata.custom:
        for key, value in metadata.custom.items():
            metadata_lines.append(f"{key}: {value}")

    # Добавляем timestamp обработки
    metadata_lines.append(f"Время индексации: {datetime.utcnow().isoformat()}")
    metadata_lines.append("[/DOCUMENT_METADATA]\n")

    # Объединяем с контентом
    enriched = "\n".join(metadata_lines) + "\n" + content
    return enriched

@app.post("/api/upload_with_metadata")
async def upload_with_metadata(
    file: UploadFile = File(...),
    metadata: str = Form(default="{}")
):
    """
    Загружает файл с метаданными в LightRAG

    Args:
        file: Файл для загрузки
        metadata: JSON строка с метаданными
    """
    try:
        # Парсим метаданные
        metadata_dict = json.loads(metadata)
        metadata_obj = MetadataModel(**metadata_dict)

        # Читаем файл
        content = await file.read()
        text_content = content.decode('utf-8')

        # Обогащаем метаданными
        enriched_content = enrich_content_with_metadata(text_content, metadata_obj)

        # Отправляем в LightRAG
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                f"{LIGHTRAG_API_URL}/documents/text",
                json={"content": enriched_content},
                headers={"X-API-Key": LIGHTRAG_API_KEY}
            )
            response.raise_for_status()

        result = response.json()
        result["metadata_applied"] = True
        result["original_filename"] = file.filename

        return result

    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid metadata JSON")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/text_with_metadata")
async def text_with_metadata(data: TextWithMetadata):
    """
    Загружает текст с метаданными в LightRAG
    """
    try:
        # Обогащаем метаданными
        enriched_content = enrich_content_with_metadata(data.content, data.metadata)

        # Отправляем в LightRAG
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                f"{LIGHTRAG_API_URL}/documents/text",
                json={"content": enriched_content},
                headers={"X-API-Key": LIGHTRAG_API_KEY}
            )
            response.raise_for_status()

        result = response.json()
        result["metadata_applied"] = True

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    """Проверка работоспособности прокси и LightRAG"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{LIGHTRAG_API_URL}/health")
            lightrag_status = "healthy" if response.status_code == 200 else "unhealthy"
    except:
        lightrag_status = "unreachable"

    return {
        "proxy_status": "healthy",
        "lightrag_status": lightrag_status,
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9622)
```

### Docker Compose интеграция

```yaml
# Добавить в docker-compose.yml

services:
  # ... существующие сервисы ...

  lightrag-proxy:
    build: ./lightrag-proxy
    container_name: service_lightrag_proxy
    hostname: lightrag-proxy
    restart: unless-stopped
    environment:
      - TZ=${TZ}
      - LIGHTRAG_API_URL=http://lightrag:9621
      - LIGHTRAG_API_KEY=${TOKEN_SECRET}
    ports:
      - "127.0.0.1:9622:9622"  # Только localhost или через Traefik
    depends_on:
      - lightrag
    networks:
      - internal
    volumes:
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
```

### Dockerfile для прокси

```dockerfile
# lightrag-proxy/Dockerfile

FROM python:3.11-slim

WORKDIR /app

# Установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода
COPY app.py .

# Запуск
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "9622"]
```

### requirements.txt

```txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
httpx==0.26.0
pydantic==2.5.3
python-multipart==0.0.6
```

### Использование из Node-RED

```javascript
// Node-RED Function node

const formData = new FormData();
formData.append('file', msg.payload);
formData.append('metadata', JSON.stringify({
    author: msg.author || 'Unknown',
    date: new Date().toISOString(),
    category: msg.category || 'general',
    tags: msg.tags || []
}));

msg.url = 'http://lightrag-proxy:9622/api/upload_with_metadata';
msg.payload = formData;
msg.headers = {
    'Content-Type': 'multipart/form-data'
};

return msg;
```

### Использование из curl

```bash
# Загрузка файла с метаданными
curl -X POST "http://localhost:9622/api/upload_with_metadata" \
  -F "file=@document.txt" \
  -F 'metadata={"author":"Иванов","category":"docs","tags":["важно"]}'

# Загрузка текста с метаданными
curl -X POST "http://localhost:9622/api/text_with_metadata" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Текст документа",
    "metadata": {
      "author": "Петров",
      "date": "2025-01-15"
    }
  }'
```

### Преимущества решения

1. **REST API** - простая интеграция с Node-RED, Flowise, любыми HTTP клиентами
2. **Автоматическая обработка** - LightRAG сам делает chunking, extraction entities
3. **Гибкость метаданных** - любые поля, любая структура
4. **Изоляция** - прокси не влияет на основной LightRAG
5. **Масштабируемость** - можно запустить несколько инстансов
6. **Легкость разработки** - FastAPI, 150 строк кода
7. **Мониторинг** - отдельный health endpoint

### Недостатки и ограничения

1. **Дополнительный сервис** - нужно поддерживать
2. **Метаданные в тексте** - не отдельные поля в БД
3. **Небольшой overhead** - дополнительный HTTP hop
4. **Зависимость** - если прокси упал, загрузка с метаданными недоступна

## Поддержка различных форматов файлов

### Архитектура парсинга

```
Файл → Определение типа → Парсер → Текст → Обогащение метаданными → LightRAG
         (по MIME/ext)      (PDF/CSV/JSON/DOCX)
```

### Полная реализация с поддержкой форматов

```python
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
import httpx
import json
import csv
import io
from typing import Optional, Dict, Any, BinaryIO
from datetime import datetime
import mimetypes

# Парсеры для разных форматов
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
    import openpyxl
    EXCEL_SUPPORT = True
except ImportError:
    EXCEL_SUPPORT = False

try:
    import markdown
    MD_SUPPORT = True
except ImportError:
    MD_SUPPORT = False

app = FastAPI(title="LightRAG Universal Metadata Proxy")

# ... MetadataModel и enrich_content_with_metadata из предыдущего примера ...

class FileParser:
    """Универсальный парсер файлов"""

    @staticmethod
    async def parse_pdf(file_content: bytes) -> str:
        """Извлекает текст из PDF"""
        if not PDF_SUPPORT:
            raise HTTPException(500, "PDF support not installed. Install PyPDF2")

        pdf_file = io.BytesIO(file_content)
        pdf_reader = PyPDF2.PdfReader(pdf_file)

        text_parts = []
        for page_num, page in enumerate(pdf_reader.pages, 1):
            text = page.extract_text()
            text_parts.append(f"--- Страница {page_num} ---\n{text}\n")

        return "\n".join(text_parts)

    @staticmethod
    async def parse_docx(file_content: bytes) -> str:
        """Извлекает текст из DOCX"""
        if not DOCX_SUPPORT:
            raise HTTPException(500, "DOCX support not installed. Install python-docx")

        doc_file = io.BytesIO(file_content)
        doc = Document(doc_file)

        text_parts = []
        for para in doc.paragraphs:
            if para.text.strip():
                text_parts.append(para.text)

        # Извлекаем текст из таблиц
        for table in doc.tables:
            for row in table.rows:
                row_text = " | ".join(cell.text for cell in row.cells)
                text_parts.append(row_text)

        return "\n\n".join(text_parts)

    @staticmethod
    async def parse_csv(file_content: bytes, encoding: str = 'utf-8') -> str:
        """Извлекает данные из CSV и форматирует в текст"""
        try:
            content = file_content.decode(encoding)
        except UnicodeDecodeError:
            # Попытка с другой кодировкой
            content = file_content.decode('latin-1')

        csv_file = io.StringIO(content)
        reader = csv.DictReader(csv_file)

        text_parts = ["CSV Data:\n"]
        for i, row in enumerate(reader, 1):
            row_text = f"Запись {i}:\n"
            for key, value in row.items():
                row_text += f"  - {key}: {value}\n"
            text_parts.append(row_text)

        return "\n".join(text_parts)

    @staticmethod
    async def parse_json(file_content: bytes) -> str:
        """Форматирует JSON в читаемый текст"""
        try:
            data = json.loads(file_content.decode('utf-8'))
        except json.JSONDecodeError as e:
            raise HTTPException(400, f"Invalid JSON: {str(e)}")

        def json_to_text(obj, level=0):
            """Рекурсивно преобразует JSON в текст"""
            indent = "  " * level
            lines = []

            if isinstance(obj, dict):
                for key, value in obj.items():
                    if isinstance(value, (dict, list)):
                        lines.append(f"{indent}{key}:")
                        lines.append(json_to_text(value, level + 1))
                    else:
                        lines.append(f"{indent}{key}: {value}")
            elif isinstance(obj, list):
                for i, item in enumerate(obj, 1):
                    if isinstance(item, (dict, list)):
                        lines.append(f"{indent}Элемент {i}:")
                        lines.append(json_to_text(item, level + 1))
                    else:
                        lines.append(f"{indent}- {item}")
            else:
                lines.append(f"{indent}{obj}")

            return "\n".join(lines)

        return "JSON Content:\n" + json_to_text(data)

    @staticmethod
    async def parse_excel(file_content: bytes) -> str:
        """Извлекает данные из Excel"""
        if not EXCEL_SUPPORT:
            raise HTTPException(500, "Excel support not installed. Install openpyxl")

        excel_file = io.BytesIO(file_content)
        workbook = openpyxl.load_workbook(excel_file, data_only=True)

        text_parts = []
        for sheet_name in workbook.sheetnames:
            sheet = workbook[sheet_name]
            text_parts.append(f"\n--- Лист: {sheet_name} ---\n")

            for row_idx, row in enumerate(sheet.iter_rows(values_only=True), 1):
                row_text = " | ".join(str(cell) if cell is not None else "" for cell in row)
                if row_text.strip():
                    text_parts.append(f"Строка {row_idx}: {row_text}")

        return "\n".join(text_parts)

    @staticmethod
    async def parse_markdown(file_content: bytes) -> str:
        """Конвертирует Markdown в текст (опционально в HTML)"""
        text = file_content.decode('utf-8')

        if MD_SUPPORT:
            # Можно конвертировать в HTML, но для RAG лучше оставить как есть
            # html = markdown.markdown(text)
            return text
        else:
            return text

    @staticmethod
    async def parse_text(file_content: bytes) -> str:
        """Парсит обычные текстовые файлы"""
        # Пробуем разные кодировки
        for encoding in ['utf-8', 'latin-1', 'cp1251', 'utf-16']:
            try:
                return file_content.decode(encoding)
            except UnicodeDecodeError:
                continue

        raise HTTPException(400, "Unable to decode text file with supported encodings")

    @staticmethod
    async def parse_xml(file_content: bytes) -> str:
        """Парсит XML файлы"""
        import xml.etree.ElementTree as ET

        try:
            root = ET.fromstring(file_content.decode('utf-8'))
        except ET.ParseError as e:
            raise HTTPException(400, f"Invalid XML: {str(e)}")

        def xml_to_text(element, level=0):
            indent = "  " * level
            lines = []

            # Тег и атрибуты
            tag_text = f"{indent}{element.tag}"
            if element.attrib:
                attrs = ", ".join(f"{k}={v}" for k, v in element.attrib.items())
                tag_text += f" [{attrs}]"
            lines.append(tag_text)

            # Текст
            if element.text and element.text.strip():
                lines.append(f"{indent}  {element.text.strip()}")

            # Дочерние элементы
            for child in element:
                lines.append(xml_to_text(child, level + 1))

            return "\n".join(lines)

        return "XML Content:\n" + xml_to_text(root)

async def detect_and_parse_file(file: UploadFile) -> str:
    """
    Определяет тип файла и парсит его в текст

    Поддерживаемые форматы:
    - PDF (.pdf)
    - Word (.docx)
    - Excel (.xlsx, .xls)
    - CSV (.csv)
    - JSON (.json)
    - XML (.xml)
    - Markdown (.md)
    - Текст (.txt, .log, .conf, и т.д.)
    """

    file_content = await file.read()
    filename = file.filename.lower()

    # Определение типа по расширению
    if filename.endswith('.pdf'):
        return await FileParser.parse_pdf(file_content)

    elif filename.endswith('.docx'):
        return await FileParser.parse_docx(file_content)

    elif filename.endswith(('.xlsx', '.xls')):
        return await FileParser.parse_excel(file_content)

    elif filename.endswith('.csv'):
        return await FileParser.parse_csv(file_content)

    elif filename.endswith('.json'):
        return await FileParser.parse_json(file_content)

    elif filename.endswith('.xml'):
        return await FileParser.parse_xml(file_content)

    elif filename.endswith(('.md', '.markdown')):
        return await FileParser.parse_markdown(file_content)

    elif filename.endswith(('.txt', '.log', '.conf', '.ini', '.yaml', '.yml', '.toml')):
        return await FileParser.parse_text(file_content)

    else:
        # Попытка определить по MIME типу
        mime_type, _ = mimetypes.guess_type(filename)

        if mime_type:
            if mime_type.startswith('text/'):
                return await FileParser.parse_text(file_content)
            elif mime_type == 'application/json':
                return await FileParser.parse_json(file_content)
            elif mime_type == 'application/xml':
                return await FileParser.parse_xml(file_content)

        # Последняя попытка - обработать как текст
        try:
            return await FileParser.parse_text(file_content)
        except:
            raise HTTPException(
                415,
                f"Unsupported file type: {filename}. "
                f"Supported: PDF, DOCX, XLSX, CSV, JSON, XML, MD, TXT"
            )

@app.post("/api/upload_with_metadata")
async def upload_with_metadata(
    file: UploadFile = File(...),
    metadata: str = Form(default="{}")
):
    """
    Универсальная загрузка файлов с метаданными

    Поддерживает: PDF, DOCX, XLSX, CSV, JSON, XML, MD, TXT и другие текстовые форматы
    """
    try:
        # Парсим метаданные
        metadata_dict = json.loads(metadata)
        metadata_obj = MetadataModel(**metadata_dict)

        # Добавляем информацию о файле в метаданные
        if 'custom' not in metadata_dict:
            metadata_dict['custom'] = {}
        metadata_dict['custom']['original_filename'] = file.filename
        metadata_dict['custom']['content_type'] = file.content_type
        metadata_obj = MetadataModel(**metadata_dict)

        # Парсим файл в текст
        text_content = await detect_and_parse_file(file)

        # Обогащаем метаданными
        enriched_content = enrich_content_with_metadata(text_content, metadata_obj)

        # Отправляем в LightRAG
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(
                f"{LIGHTRAG_API_URL}/documents/text",
                json={"content": enriched_content},
                headers={"X-API-Key": LIGHTRAG_API_KEY}
            )
            response.raise_for_status()

        result = response.json()
        result["metadata_applied"] = True
        result["original_filename"] = file.filename
        result["file_type"] = file.content_type
        result["parsed"] = True

        return result

    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid metadata JSON")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing error: {str(e)}")

@app.get("/api/supported_formats")
async def supported_formats():
    """Возвращает список поддерживаемых форматов"""
    return {
        "text_formats": [".txt", ".log", ".conf", ".ini", ".yaml", ".yml", ".toml"],
        "document_formats": {
            "pdf": {"supported": PDF_SUPPORT, "extensions": [".pdf"]},
            "docx": {"supported": DOCX_SUPPORT, "extensions": [".docx"]},
        },
        "spreadsheet_formats": {
            "excel": {"supported": EXCEL_SUPPORT, "extensions": [".xlsx", ".xls"]},
            "csv": {"supported": True, "extensions": [".csv"]},
        },
        "data_formats": [".json", ".xml"],
        "markdown_formats": {
            "markdown": {"supported": MD_SUPPORT, "extensions": [".md", ".markdown"]}
        }
    }
```

### Обновленный requirements.txt

```txt
# Основные зависимости
fastapi==0.109.0
uvicorn[standard]==0.27.0
httpx==0.26.0
pydantic==2.5.3
python-multipart==0.0.6

# Парсеры файлов
PyPDF2==3.0.1           # PDF
python-docx==1.1.0      # DOCX
openpyxl==3.1.2         # Excel
markdown==3.5.1         # Markdown (опционально)

# Дополнительные утилиты
python-magic==0.4.27    # Определение MIME типов (опционально)
chardet==5.2.0          # Определение кодировок (опционально)
```

### Примеры использования

```bash
# PDF с метаданными
curl -X POST "http://localhost:9622/api/upload_with_metadata" \
  -F "file=@document.pdf" \
  -F 'metadata={"author":"Иванов","category":"отчеты","department":"финансы"}'

# Excel таблица
curl -X POST "http://localhost:9622/api/upload_with_metadata" \
  -F "file=@sales_data.xlsx" \
  -F 'metadata={"category":"статистика","tags":["продажи","Q1-2025"]}'

# JSON конфигурация
curl -X POST "http://localhost:9622/api/upload_with_metadata" \
  -F "file=@config.json" \
  -F 'metadata={"source":"api","version":"2.0"}'

# CSV данные
curl -X POST "http://localhost:9622/api/upload_with_metadata" \
  -F "file=@users.csv" \
  -F 'metadata={"category":"пользователи","date":"2025-01-15"}'

# Проверка поддерживаемых форматов
curl "http://localhost:9622/api/supported_formats"
```

### Альтернативные улучшения

#### 1. Поддержка batch upload

```python
@app.post("/api/batch_upload")
async def batch_upload(
    files: list[UploadFile] = File(...),
    metadata: str = Form(default="{}")
):
    """Массовая загрузка файлов с общими метаданными"""
    metadata_dict = json.loads(metadata)

    results = []
    for file in files:
        try:
            # Парсим каждый файл
            text_content = await detect_and_parse_file(file)

            # Добавляем имя файла в метаданные
            file_metadata = metadata_dict.copy()
            if 'custom' not in file_metadata:
                file_metadata['custom'] = {}
            file_metadata['custom']['original_filename'] = file.filename

            metadata_obj = MetadataModel(**file_metadata)
            enriched_content = enrich_content_with_metadata(text_content, metadata_obj)

            # Отправляем в LightRAG
            async with httpx.AsyncClient(timeout=300.0) as client:
                response = await client.post(
                    f"{LIGHTRAG_API_URL}/documents/text",
                    json={"content": enriched_content},
                    headers={"X-API-Key": LIGHTRAG_API_KEY}
                )
                response.raise_for_status()

            results.append({
                "filename": file.filename,
                "status": "success",
                "track_id": response.json().get("track_id")
            })

        except Exception as e:
            results.append({
                "filename": file.filename,
                "status": "failed",
                "error": str(e)
            })

    return {
        "total": len(files),
        "successful": len([r for r in results if r["status"] == "success"]),
        "failed": len([r for r in results if r["status"] == "failed"]),
        "results": results
    }
```

#### 2. OCR для изображений и сканов

```python
try:
    import pytesseract
    from PIL import Image
    OCR_SUPPORT = True
except ImportError:
    OCR_SUPPORT = False

class FileParser:
    # ... существующие методы ...

    @staticmethod
    async def parse_image(file_content: bytes) -> str:
        """Извлекает текст из изображения через OCR"""
        if not OCR_SUPPORT:
            raise HTTPException(500, "OCR support not installed. Install pytesseract and Pillow")

        image = Image.open(io.BytesIO(file_content))
        text = pytesseract.image_to_string(image, lang='rus+eng')

        return f"[Текст извлечен через OCR]\n\n{text}"

# В detect_and_parse_file добавить:
elif filename.endswith(('.png', '.jpg', '.jpeg', '.tiff', '.bmp')):
    return await FileParser.parse_image(file_content)
```

#### 3. Валидация и очистка текста

```python
def clean_text(text: str) -> str:
    """Очищает и нормализует извлеченный текст"""
    import re

    # Удаляем лишние пробелы
    text = re.sub(r'\s+', ' ', text)

    # Удаляем управляющие символы
    text = re.sub(r'[\x00-\x08\x0b-\x0c\x0e-\x1f\x7f-\x9f]', '', text)

    # Нормализуем переводы строк
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()
```

### Заключение

Промежуточный прокси-сервис - это оптимальное решение для добавления метаданных в LightRAG:

- ✅ Простая интеграция через REST API
- ✅ Использование нативных возможностей LightRAG
- ✅ Минимальная разработка (1-2 дня)
- ✅ Легкое развертывание в существующей инфраструктуре

Рекомендуется к внедрению для production использования.
