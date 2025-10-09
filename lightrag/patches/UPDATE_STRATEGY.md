# 🔄 Стратегия обновления LightRAG с патчами

## 🎯 Что происходит при обновлении образа?

### Текущая конфигурация:
```yaml
lightrag:
  image: ghcr.io/hkuds/lightrag:latest
  volumes:
    - ./lightrag/patches/document_routes.py:/app/lightrag/api/routers/document_routes.py:ro
```

### При `docker pull ghcr.io/hkuds/lightrag:latest`:

1. ✅ **Патч продолжает работать**
   - Volume mount перезаписывает файл внутри нового контейнера
   - Наш исправленный файл имеет приоритет

2. ⚠️ **Возможные проблемы:**
   - Если в новой версии изменилась структура файла
   - Если добавились новые поля в модель `DocStatusResponse`
   - Если изменились import'ы или зависимости

---

## 🔍 Сценарии обновления

### Сценарий 1: Баг исправлен в upstream ✅
**Что делать:**
```bash
# 1. Проверить changelog новой версии
docker pull ghcr.io/hkuds/lightrag:latest
docker run --rm ghcr.io/hkuds/lightrag:latest cat /app/lightrag/api/routers/document_routes.py | grep -A2 "file_path"

# 2. Если баг исправлен (file_path: Optional[str]):
# Удалить volume mount из docker-compose.yml
# Комментарий в коммите: "Remove patch - fixed in upstream v1.x.x"

# 3. Удалить патч (но оставить в истории git)
git mv lightrag/patches/document_routes.py lightrag/patches/DEPRECATED_document_routes.py
git commit -m "Deprecate document_routes.py patch - fixed in upstream"
```

### Сценарий 2: Конфликт с новой версией ⚠️
**Признаки:**
```bash
# Контейнер падает при старте
docker logs service_lightrag
# Ошибка: ImportError, SyntaxError, ValidationError
```

**Что делать:**
```bash
# 1. Извлечь новую версию файла
docker run --rm ghcr.io/hkuds/lightrag:latest cat /app/lightrag/api/routers/document_routes.py > /tmp/new_version.py

# 2. Сравнить с нашим патчем
diff lightrag/patches/document_routes.py /tmp/new_version.py | head -50

# 3. Обновить патч (объединить изменения)
# - Скопировать новую версию файла
# - Применить наше исправление (file_path: Optional[str])
cp /tmp/new_version.py lightrag/patches/document_routes.py
# Редактировать файл, добавив Optional[str] для file_path

# 4. Пересоздать контейнер и тестировать
docker compose up -d --force-recreate lightrag
curl -X POST "https://your-domain.com:7040/documents/paginated" ...
```

### Сценарий 3: Патч больше не нужен (новая архитектура) 🔄
**Признаки:**
- Файл `document_routes.py` переименован/перенесён
- Модель `DocStatusResponse` больше не используется
- Новый механизм работы с документами

**Что делать:**
```bash
# 1. Изучить новую архитектуру
docker exec service_lightrag find /app -name "*document*" -type f

# 2. Создать новый патч (если нужен)
# Или удалить старый volume mount

# 3. Документировать изменения
echo "Patch deprecated since LightRAG v2.0 - architecture changed" >> lightrag/patches/README.md
```

---

## 🛡️ Проактивная стратегия

### 1. Мониторинг upstream репозитория
```bash
# Следить за релизами
# https://github.com/hkuds/lightrag/releases

# Подписаться на Pull Requests, связанные с document_routes.py
# https://github.com/hkuds/lightrag/pulls?q=document_routes
```

### 2. Автоматическая проверка совместимости
Создать скрипт `lightrag/patches/check_compatibility.sh`:

```bash
#!/bin/bash
# Проверка совместимости патча с новой версией образа

echo "🔍 Checking LightRAG patch compatibility..."

# Скачать новый образ
docker pull ghcr.io/hkuds/lightrag:latest

# Извлечь файл из нового образа
NEW_FILE=$(docker run --rm ghcr.io/hkuds/lightrag:latest cat /app/lightrag/api/routers/document_routes.py)

# Проверить, что файл существует
if [ -z "$NEW_FILE" ]; then
    echo "⚠️  WARNING: File not found in new image!"
    exit 1
fi

# Проверить строку с file_path
if echo "$NEW_FILE" | grep -q "file_path: Optional\[str\]"; then
    echo "✅ Patch no longer needed - fixed in upstream!"
    echo "🗑️  Consider removing volume mount from docker-compose.yml"
else
    echo "⚠️  Patch still needed"

    # Проверить, что структура не изменилась критично
    if echo "$NEW_FILE" | grep -q "class DocStatusResponse"; then
        echo "✅ Model structure compatible"
    else
        echo "❌ Model structure changed - manual update required!"
        exit 2
    fi
fi
```

### 3. Версионирование патчей
```bash
lightrag/patches/
├── README.md
├── UPDATE_STRATEGY.md
├── document_routes.py              # Текущий патч
├── document_routes.v1.4.8.py       # Патч для конкретной версии
└── check_compatibility.sh          # Скрипт проверки
```

---

## 📋 Чеклист при обновлении LightRAG

```markdown
### Перед обновлением:
- [ ] Проверить changelog: https://github.com/hkuds/lightrag/releases
- [ ] Поискать упоминания "file_path" или "DocStatusResponse" в изменениях
- [ ] Сделать backup данных: `docker exec service_lightrag tar -czf /tmp/backup.tar.gz /app/data/rag_storage/`

### Процесс обновления:
- [ ] Скачать новый образ: `docker pull ghcr.io/hkuds/lightrag:latest`
- [ ] Проверить совместимость патча (скрипт выше)
- [ ] Обновить контейнер: `docker compose up -d --force-recreate lightrag`
- [ ] Проверить логи: `docker logs service_lightrag --tail 50`

### После обновления:
- [ ] Протестировать endpoint: `curl -X POST .../documents/paginated`
- [ ] Проверить веб-интерфейс: https://your-domain.com:7040/docs
- [ ] Обновить документацию патчей (если нужно)
```

---

## 🎯 Рекомендации

### Короткосрочные (1-3 месяца):
1. ✅ Оставить патч как есть
2. 👀 Следить за обновлениями LightRAG
3. 🧪 Тестировать при каждом обновлении образа

### Среднесрочные (3-6 месяцев):
1. 📬 Создать Issue в репозитории LightRAG:
   ```
   Title: DocStatusResponse.file_path should be Optional for text-inserted documents

   Description:
   When inserting documents via /documents/text endpoint, file_path is null in storage,
   but DocStatusResponse model requires it to be a string, causing validation errors
   in /documents/paginated endpoint.

   Suggested fix: file_path: Optional[str] = Field(default=None, ...)
   ```

2. 🔀 Или создать Pull Request с исправлением

### Долгосрочные (6+ месяцев):
1. 🎉 Если PR принят → удалить патч
2. 🔄 Если upstream не реагирует → форкнуть репозиторий и поддерживать свою версию
3. 🏗️ Или перейти на альтернативное решение (свой Docker образ с исправлением)

---

## 🚀 Альтернативные подходы

### Вариант 1: Свой Docker образ (наиболее надёжно)
```dockerfile
# lightrag/Dockerfile
FROM ghcr.io/hkuds/lightrag:latest

# Копируем исправленный файл
COPY patches/document_routes.py /app/lightrag/api/routers/document_routes.py

# Очищаем Python кэш
RUN find /app -type f -name "*.pyc" -delete && \
    find /app -type d -name "__pycache__" -exec rm -rf {} +
```

```yaml
# docker-compose.yml
lightrag:
  build:
    context: ./lightrag
    dockerfile: Dockerfile
  # Без volume mount для патча
```

### Вариант 2: Init container для применения патчей
```yaml
lightrag-init:
  image: ghcr.io/hkuds/lightrag:latest
  command: sh -c "cp /patches/* /app/lightrag/api/routers/ && find /app -name '*.pyc' -delete"
  volumes:
    - ./lightrag/patches:/patches:ro
    - lightrag_code:/app

lightrag:
  depends_on:
    - lightrag-init
  volumes:
    - lightrag_code:/app
```

### Вариант 3: Fork репозитория (для множественных изменений)
```bash
# 1. Fork на GitHub: https://github.com/hkuds/lightrag
# 2. Клонировать и применить патчи
# 3. Собрать свой образ
# 4. Использовать в docker-compose.yml

lightrag:
  image: your-dockerhub-username/lightrag:patched-v1.4.8
```

---

**Текущий статус:** 🟢 Volume mount работает стабильно
**Рекомендация:** Следить за upstream, создать Issue в GitHub
**План Б:** При конфликтах переходить на свой Docker образ
