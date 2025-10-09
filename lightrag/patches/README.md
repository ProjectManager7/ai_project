# LightRAG Patches

Этот каталог содержит патчи для исправления багов в официальном образе LightRAG (`ghcr.io/hkuds/lightrag:latest`).

## 📋 Список патчей

### 1. `document_routes.py` - Исправление ошибки валидации file_path

**Проблема:**
```
Failed to load documents 500
{
  "detail":"1 validation error for DocStatusResponse\nfile_path\n
  Input should be a valid string [type=string_type, input_value=None, input_type=NoneType]\n
  For further information visit https://errors.pydantic.dev/2.11/v/string_type"
}
/documents/paginated
```

**Причина:**
Модель Pydantic `DocStatusResponse` определяла поле `file_path` как обязательную строку (`str`), но документы, вставленные через текстовый API (`/documents/text`), имеют `file_path=null` в базе данных.

**Исправление:**
Изменение определения поля `file_path` с:
```python
file_path: str = Field(description="Path to the document file")
```

на:
```python
file_path: Optional[str] = Field(
    default=None, description="Path to the document file"
)
```

**Файлы:**
- Оригинальный файл: `/app/lightrag/api/routers/document_routes.py` (внутри контейнера)
- Патч: `./lightrag/patches/document_routes.py` (локальная копия с исправлением)
- Строка: ~374

**Монтирование:**
В `docker-compose.yml` добавлен volume mount:
```yaml
volumes:
  - ./lightrag/patches/document_routes.py:/app/lightrag/api/routers/document_routes.py:ro
```

**Статус:** ✅ Применён и протестирован

**Тестирование:**
```bash
curl -X POST "https://your-domain.com:7040/documents/paginated" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"page": 1, "page_size": 10}' \
  -k
```

**Результат:**
Endpoint теперь корректно возвращает список документов, включая документы с `file_path: null`.

---

## 🔄 Применение патчей

После добавления нового патча:

1. Поместите исправленный файл в `./lightrag/patches/`
2. Добавьте volume mount в `docker-compose.yml`
3. Пересоздайте контейнер:
   ```bash
   docker compose up -d --force-recreate lightrag
   ```
4. Проверьте, что патч применён:
   ```bash
   docker exec service_lightrag cat /app/path/to/file.py | grep "your-change"
   ```

## 🔍 Проверка совместимости при обновлении

**При обновлении LightRAG до новой версии:**

```bash
# Автоматическая проверка совместимости патча
cd /root/ai_project
./lightrag/patches/check_compatibility.sh
```

Скрипт проверит:
- ✅ Существует ли файл в новой версии образа
- ✅ Исправлен ли баг в upstream
- ✅ Совместима ли структура модели
- ✅ Корректен ли синтаксис патча

**Что делать при обновлении:**
- Если баг исправлен → удалить volume mount из `docker-compose.yml`
- Если патч несовместим → обновить патч вручную
- Подробности в [UPDATE_STRATEGY.md](UPDATE_STRATEGY.md)

## 📝 История изменений

- **2025-10-09**: Создан патч для `document_routes.py` - исправление валидации `file_path`
