from flask import Blueprint, request, jsonify
from chroma_utils import ChromaManager
from readers import DocumentReader
import logging
from datetime import datetime
import json
import os

# Получаем путь к текущей директории
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
ERROR_LOG_PATH = os.path.join(CURRENT_DIR, 'error.txt')

# Настройка основного логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)

def log_error(error_msg: str):
    """
    Логирование ошибок в отдельный файл
    """
    try:
        # Формируем строку с датой и ошибкой
        current_time = datetime.now().strftime('%d.%m.%Y %H:%M:%S')
        error_json = json.dumps({"error": str(error_msg)})
        log_entry = f"{current_time}\n{error_json}\n\n"

        # Записываем в файл
        with open(ERROR_LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(log_entry)
    except Exception as e:
        logging.error(f"Error in error logging: {str(e)}")

app1 = Blueprint('app1', __name__)
# Отложенная инициализация - создание при первом запросе
chroma_manager = None

def get_chroma_manager():
    """Ленивая инициализация ChromaManager"""
    global chroma_manager
    if chroma_manager is None:
        chroma_manager = ChromaManager()
    return chroma_manager

@app1.route('/health', methods=['GET'])
def health():
    """
    Health Check endpoint для Docker и Traefik
    Проверяет работоспособность API и подключение к ChromaDB
    """
    try:
        # Проверяем подключение к ChromaDB
        get_chroma_manager().client.heartbeat()
        return jsonify({
            "status": "healthy",
            "service": "chroma-api",
            "chroma_connected": True
        }), 200
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "service": "chroma-api",
            "chroma_connected": False,
            "error": str(e)
        }), 503

@app1.route('/api', methods=['POST'])
def api():
    try:
        # 🔒 Проверка токена безопасности
        api_token = request.headers.get('x-chroma-api-token')
        expected_token = os.getenv('CHROMA_API_TOKEN')

        if not api_token or api_token != expected_token:
            error_msg = "Unauthorized: Invalid or missing API token"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 401

        data = request.get_json()
        if not data:
            error_msg = "No JSON data provided"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        action = data.get('action')
        if not action:
            error_msg = "No action specified"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        # Маршрутизация действий
        handlers = {
            'upsert': handle_upsert,
            'upsert_json': handle_upsert_json,
            'delete_file': handle_delete_file,
            'delete_collection': handle_delete_collection,
            'show_collection': handle_show_collection,
            'count': handle_count,
            'query': handle_query
        }

        handler = handlers.get(action)
        if not handler:
            error_msg = f"Unknown action: {action}"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        return handler(data)

    except Exception as e:
        error_msg = f"Error in api endpoint: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500

def handle_upsert(data):
    """
    Обработка загрузки файлов
    """
    try:
        file_url = data.get('file_name')
        if not file_url:
            error_msg = "file_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        logging.info(f"Starting file upload from {file_url} to collection {collection_name}")

        # Читаем содержимое файла с параметрами разделения на чанки
        content = DocumentReader.read_file(
            file_url,
            chunk_size=data.get('chunk_size'),
            chunk_overlap=data.get('chunk_overlap'),
            custom_separators=data.get('custom_separators')
        )

        # Убеждаемся, что content - это список
        if not isinstance(content, list):
            content = [content]

        # Подготавливаем метаданные
        metadata = data.get('metadata')
        metadata_list = [metadata] * len(content) if metadata else None

        # Загружаем документы с переданным api_key
        result = get_chroma_manager().add_documents(
            collection_name=collection_name,
            texts=content,
            metadata=metadata_list,
            api_key=data.get('openai_api_key'),
            model_name=data.get('model_name')
        )

        logging.info(f"Successfully uploaded to collection {collection_name}")
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in upsert: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500

def handle_upsert_json(data):
    """
    Обработка загрузки JSON данных с учётом кастомной метадаты для каждого чанка.
    """
    try:
        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        json_data = data.get('json_data')
        if not json_data:
            error_msg = "json_data is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        separate_chunks = data.get('separate_chunks', False)

        texts = []
        metadata_list = []

        # Получаем глобальную метадату (если есть)
        global_metadata = data.get('metadata', {})
        if global_metadata is None:
            global_metadata = {}
        elif not isinstance(global_metadata, dict):
            error_msg = "Глобальная metadata должна быть объектом"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        if separate_chunks:
            # Ожидаем, что данные передаются в виде { "questions": [ ... ] }
            chunks = json_data.get('questions')
            if chunks and isinstance(chunks, list):
                for chunk in chunks:
                    if isinstance(chunk, dict):
                        # Извлекаем текст из поля "text"
                        text = chunk.get('text')
                        if not text:
                            text = ""
                        texts.append(text)

                        # Извлекаем метадату для этого чанка (если есть)
                        chunk_metadata = chunk.get('metadata', {})
                        if chunk_metadata is None:
                            chunk_metadata = {}
                        elif not isinstance(chunk_metadata, dict):
                            error_msg = "Поле metadata для чанка должно быть объектом"
                            log_error(error_msg)
                            return jsonify({"error": error_msg}), 400

                        # Объединяем глобальную метадату и метадату чанка
                        merged_metadata = dict(global_metadata)
                        merged_metadata.update(chunk_metadata)

                        # Если ключ 'source' отсутствует, добавляем его
                        if 'source' not in merged_metadata:
                            merged_metadata['source'] = 'api'
                        metadata_list.append(merged_metadata)
                    else:
                        texts.append(str(chunk))
                        merged_metadata = dict(global_metadata)
                        if 'source' not in merged_metadata:
                            merged_metadata['source'] = 'api'
                        metadata_list.append(merged_metadata)
            else:
                texts.append(json.dumps(json_data, ensure_ascii=False, indent=2))
                merged_metadata = dict(global_metadata)
                if 'source' not in merged_metadata:
                    merged_metadata['source'] = 'api'
                metadata_list.append(merged_metadata)
        else:
            texts.append(json.dumps(json_data, ensure_ascii=False, indent=2))
            merged_metadata = dict(global_metadata)
            if 'source' not in merged_metadata:
                merged_metadata['source'] = 'api'
            metadata_list.append(merged_metadata)

        result = get_chroma_manager().add_documents(
            collection_name=collection_name,
            texts=texts,
            metadata=metadata_list,
            api_key=data.get('openai_api_key'),
            model_name=data.get('model_name')
        )
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in upsert_json: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500


def handle_delete_file(data):
    """
    Обработка удаления файлов по метаданным
    """
    try:
        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        filters = data.get('filters', {})

        result = get_chroma_manager().delete_documents(
            collection_name=collection_name,
            filters=filters
        )
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in delete_file: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500

def handle_delete_collection(data):
    """
    Обработка удаления коллекции
    """
    try:
        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        result = get_chroma_manager().delete_collection(collection_name)
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in delete_collection: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500

def handle_show_collection(data):
    """
    Обработка показа содержимого коллекции
    """
    try:
        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        filters = data.get('filters', {})

        result = get_chroma_manager().get_documents(
            collection_name=collection_name,
            filters=filters
        )
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in show_collection: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500

def handle_count(data):
    """
    Обработка подсчета документов в коллекции
    """
    try:
        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        result = get_chroma_manager().count_documents(collection_name)
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in count: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500

def handle_query(data):
    """
    Обработка поисковых запросов с учетом фильтров
    """
    try:
        collection_name = data.get('collection_name')
        if not collection_name:
            error_msg = "collection_name is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        query_text = data.get('query')
        if not query_text:
            error_msg = "query is required"
            log_error(error_msg)
            return jsonify({"error": error_msg}), 400

        n_results = data.get('n_results', 4)
        model_name = data.get('model_name', 'text-embedding-3-large')
        filters = data.get('filters')  # Получаем фильтры из запроса

        result = get_chroma_manager().query_collection(
            collection_name=collection_name,
            query_text=query_text,
            n_results=n_results,
            api_key=data.get('openai_api_key'),
            model_name=model_name,
            filters=filters  # Передаём фильтры в функцию
        )
        return jsonify(result)

    except Exception as e:
        error_msg = f"Error in query: {str(e)}"
        log_error(error_msg)
        return jsonify({"error": error_msg}), 500
