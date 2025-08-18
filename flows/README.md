# 📁 Flows Configuration Directory

## 📋 Назначение

Эта папка предназначена для хранения экспортированных конфигураций Node-RED flows и Flowise chatflows **БЕЗ CREDENTIALS**.

## 🗂 Структура папки

```
flows/
├── README.md                    # Этот файл
├── node-red/                    # Node-RED flows
│   ├── telegram-bot.json        # Telegram бот flow
│   ├── webhook-handler.json     # Webhook обработчики
│   └── automation-flows.json    # Автоматизация
├── flowise/                     # Flowise AI chatflows  
│   ├── customer-support.json    # Чатбот поддержки
│   ├── content-generator.json   # Генератор контента
│   └── data-analysis.json       # Анализ данных
└── templates/                   # Шаблоны для быстрого старта
    ├── basic-telegram-bot.template.json
    └── simple-chatflow.template.json
```

## ⚠️ ВАЖНО: Безопасность

### ✅ ЧТО можно коммитить в git:
- ✅ Flow конфигурации **БЕЗ credentials**
- ✅ Шаблоны flows  
- ✅ Структурные конфигурации
- ✅ Документацию по flows

### ❌ ЧТО НЕЛЬЗЯ коммитить:
- ❌ API ключи (OpenAI, Telegram, etc.)
- ❌ Пароли баз данных
- ❌ Токены аутентификации
- ❌ Файлы с расширением `.credentials`

## 🔄 Экспорт flows (без credentials)

### Node-RED экспорт:

```bash
# Через UI Node-RED:
# 1. Откройте http://your-domain.com
# 2. Menu (☰) → Export
# 3. Выберите нужные flows
# 4. ⚠️ ОБЯЗАТЕЛЬНО снимите галочку "Include credentials"
# 5. Скопируйте JSON в файл flows/node-red/your-flow.json

# Через API:
curl -X GET http://localhost:1880/flows > flows/node-red/exported-flows.json
```

### Flowise экспорт:

```bash
# Через UI Flowise:
# 1. Откройте https://your-domain.com:5050
# 2. Chatflows → Выберите chatflow → Export
# 3. Сохраните JSON в flows/flowise/your-chatflow.json

# API ключи будут автоматически исключены из экспорта
```

## 📥 Импорт flows

### Node-RED импорт:

```bash
# Через UI Node-RED:
# 1. Menu (☰) → Import
# 2. Выберите файл flows/node-red/your-flow.json
# 3. Настройте credentials вручную после импорта

# Через API:
curl -X POST http://localhost:1880/flows \
  -H "Content-Type: application/json" \
  -d @flows/node-red/your-flow.json
```

### Flowise импорт:

```bash
# Через UI Flowise:
# 1. Chatflows → Import
# 2. Выберите файл flows/flowise/your-chatflow.json
# 3. Настройте API ключи после импорта
```

## 🛠 Создание папок для flows

```bash
# Создать структуру папок
mkdir -p flows/node-red
mkdir -p flows/flowise  
mkdir -p flows/templates

# Создать папки для специфичных проектов
mkdir -p flows/node-red/telegram-bots
mkdir -p flows/node-red/webhooks
mkdir -p flows/flowise/chatbots
mkdir -p flows/flowise/ai-agents
```

## 📝 Шаблоны flows

### Базовый Telegram бот (Node-RED):

```json
{
  "id": "telegram-bot-template",
  "type": "tab",
  "label": "Telegram Bot Template",
  "nodes": [
    {
      "id": "webhook-in",
      "type": "http in",
      "url": "/telegram/webhook",
      "method": "post",
      "name": "Telegram Webhook"
    },
    {
      "id": "telegram-sender",
      "type": "telegram sender",
      "botname": "${TELEGRAM_BOT_TOKEN}",
      "name": "Send to Telegram"
    }
  ]
}
```

### Базовый AI чатбот (Flowise):

```json
{
  "name": "Basic AI Chatbot",
  "flowData": {
    "nodes": [
      {
        "id": "chatOpenAI",
        "data": {
          "openAIApiKey": "${OPENAI_API_KEY}",
          "modelName": "gpt-3.5-turbo"
        }
      }
    ]
  }
}
```

## 🔄 Backup/Restore flows

### Создание backup:

```bash
# Backup всех flows
./scripts/backup-flows.sh

# Или вручную:
docker run --rm -v ai_project_nodered_data:/data -v $(pwd)/flows:/backup \
  alpine tar czf /backup/nodered-backup.tar.gz -C /data .

docker run --rm -v ai_project_flowise_data:/data -v $(pwd)/flows:/backup \
  alpine tar czf /backup/flowise-backup.tar.gz -C /data .
```

### Восстановление из backup:

```bash
# Restore flows  
./scripts/restore-flows.sh

# Или вручную:
docker run --rm -v ai_project_nodered_data:/data -v $(pwd)/flows:/backup \
  alpine tar xzf /backup/nodered-backup.tar.gz -C /data

docker run --rm -v ai_project_flowise_data:/data -v $(pwd)/flows:/backup \
  alpine tar xzf /backup/flowise-backup.tar.gz -C /data
```

## 🔧 Настройка credentials после импорта

### Node-RED:
1. Откройте imported flow
2. Найдите nodes с красным треугольником (missing credentials)
3. Дважды кликните на node
4. Добавьте credentials в соответствующие поля
5. Deploy changes

### Flowise:
1. Откройте imported chatflow  
2. Найдите nodes с отсутствующими API ключами
3. Кликните на node и добавьте API ключи
4. Save chatflow

## 📚 Примеры использования

### Для разработчика:
```bash
# 1. Создайте новый flow в Node-RED
# 2. Экспортируйте без credentials
# 3. Сохраните в flows/node-red/my-new-bot.json
# 4. Коммитьте в git
git add flows/node-red/my-new-bot.json
git commit -m "Add new telegram bot flow"
```

### Для деплоя на новом сервере:
```bash
# 1. Клонируйте репозиторий
# 2. Запустите проект
# 3. Импортируйте flows из папки flows/
# 4. Настройте credentials через .env переменные
```

## 🎯 Best Practices

1. **✅ Всегда экспортируйте flows БЕЗ credentials**
2. **✅ Используйте понятные имена файлов**
3. **✅ Группируйте flows по функциональности**
4. **✅ Добавляйте описания в комментариях flows**
5. **✅ Регулярно создавайте backup**
6. **❌ Никогда не коммитьте файлы с credentials**

---

**📌 Помните: Эта папка для безопасного хранения структуры flows, а credentials управляются через .env переменные!**