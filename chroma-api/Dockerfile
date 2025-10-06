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
