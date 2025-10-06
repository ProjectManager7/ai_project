from chromadb import HttpClient
from chromadb.config import Settings
from typing import List, Dict, Any, Optional
from openai import OpenAI
import uuid
import logging
import os
import threading

class ChromaManager:
    """
    Singleton класс для управления подключением к ChromaDB
    Использует Connection Pooling - создается только один экземпляр
    """
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        """Реализация Singleton паттерна с thread-safe инициализацией"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        """Инициализация выполняется только один раз"""
        if self._initialized:
            return

        # Чтение переменных из окружения
        host = os.getenv('CHROMA_SERVER_HOST', 'service_chroma')
        port = int(os.getenv('CHROMA_SERVER_PORT', '8000'))

        # Создаем HttpClient для ChromaDB 0.5.x
        # Новая версия не требует явного указания tenant/database
        self.client = HttpClient(
            host=host,
            port=port,
            settings=Settings(anonymized_telemetry=False)
        )

        self._initialized = True
        logging.info(f"ChromaDB client initialized: {host}:{port}")

    def _create_embeddings(self, texts: List[str], api_key: Optional[str] = None,
                             model_name: Optional[str] = None) -> List[List[float]]:
        """
        Создает эмбеддинги для списка текстов с использованием OpenAI API
        """
        # Определяем модель сразу, чтобы она была доступна в exception handler
        model = model_name or os.getenv('CHROMA_MODEL', 'text-embedding-3-large')

        try:
            # Используем переданный api_key или берем из переменных окружения
            api_key = api_key or os.getenv('OPENAI_API_KEY')
            if not api_key:
                raise ValueError("OPENAI_API_KEY not found in environment variables")

            client = OpenAI(api_key=api_key)

            embeddings = []
            for text in texts:
                response = client.embeddings.create(
                    input=text,
                    model=model
                )
                embeddings.append(response.data[0].embedding)
            return embeddings
        except Exception as e:
            logging.error(f"Error creating embeddings: {str(e)}")
            logging.error(f"Model used: {model}")
            raise

    def add_documents(self, collection_name: str, texts: List[str],
                      metadata: Optional[List[Dict[str, Any]]] = None,
                      api_key: Optional[str] = None,
                      model_name: Optional[str] = None,
                      **kwargs) -> Dict[str, Any]:
        """
        Добавляет документы в коллекцию
        """
        try:
            # Получаем или создаем коллекцию
            collection = self.client.get_or_create_collection(
                name=collection_name,
                metadata={"hnsw:space": "cosine"}
            )

            # Генерируем уникальные ID для документов
            ids = [str(uuid.uuid4()) for _ in texts]

            # Создаем эмбеддинги с использованием переданного api_key и модели
            embeddings = self._create_embeddings(texts, api_key, model_name)

            # Если метаданные не переданы, создаем пустые
            if metadata is None:
                metadata = [{"source": "api"} for _ in texts]

            # Преобразуем метаданные в совместимый формат
            # ChromaDB 0.4.x требует простые типы в метаданных
            clean_metadata = []
            for meta in metadata:
                clean_meta = {}
                for key, value in meta.items():
                    # Конвертируем все в строки или числа
                    if isinstance(value, (str, int, float, bool)):
                        clean_meta[key] = value
                    else:
                        clean_meta[key] = str(value)
                clean_metadata.append(clean_meta)

            # Добавляем документы
            collection.add(
                documents=texts,
                embeddings=embeddings,
                metadatas=clean_metadata,
                ids=ids
            )

            model_used = model_name or os.getenv('CHROMA_MODEL', 'text-embedding-3-large')

            return {
                "status": "success",
                "added": len(texts),
                "ids": ids,
                "model_used": model_used
            }

        except Exception as e:
            logging.error(f"Error adding documents: {str(e)}")
            raise

    def delete_documents(self, collection_name: str, filters: Dict[str, Any]) -> Dict[str, Any]:
        """
        Удаляет документы из коллекции по фильтру
        """
        try:
            collection = self.client.get_collection(name=collection_name)

            # Получаем документы по фильтру
            result = collection.get(**filters)

            if result['ids']:
                # Удаляем найденные документы
                collection.delete(ids=result['ids'])

                return {
                    "status": "success",
                    "deleted": len(result['ids']),
                    "ids": result['ids']
                }

            return {
                "status": "success",
                "deleted": 0,
                "ids": []
            }

        except Exception as e:
            logging.error(f"Error deleting documents: {str(e)}")
            raise

    def delete_collection(self, collection_name: str) -> Dict[str, Any]:
        """
        Удаляет коллекцию
        """
        try:
            self.client.delete_collection(name=collection_name)
            return {
                "status": "success",
                "message": f"Collection {collection_name} deleted"
            }
        except Exception as e:
            logging.error(f"Error deleting collection: {str(e)}")
            raise

    def get_documents(self, collection_name: str, filters: Dict[str, Any]) -> Dict[str, Any]:
        """
        Получает документы из коллекции по фильтру
        """
        try:
            collection = self.client.get_collection(name=collection_name)
            result = collection.get(**filters)
            return result
        except Exception as e:
            logging.error(f"Error getting documents: {str(e)}")
            raise

    def count_documents(self, collection_name: str) -> Dict[str, Any]:
        """
        Подсчитывает количество документов в коллекции
        """
        try:
            collection = self.client.get_collection(name=collection_name)
            count = collection.count()
            return {
                "status": "success",
                "count": count
            }
        except Exception as e:
            logging.error(f"Error counting documents: {str(e)}")
            raise

    def query_collection(self, collection_name: str, query_text: str,
                         n_results: int = 4, api_key: Optional[str] = None,
                         model_name: Optional[str] = None,
                         filters: Optional[dict] = None) -> Dict[str, Any]:
        """
        Поиск релевантных документов по запросу с учетом фильтров.
        Если в filters переданы ключи "where" или "where_document", они будут добавлены
        в параметры запроса к коллекции.
        """
        try:
            collection = self.client.get_collection(name=collection_name)

            # Создаем эмбеддинг для запроса с указанной моделью
            query_embedding = self._create_embeddings(
                [query_text],
                api_key=api_key,
                model_name=model_name
            )[0]

            # Готовим параметры запроса
            query_params = {
                "query_embeddings": [query_embedding],
                "n_results": n_results,
                "include": ['documents', 'metadatas', 'distances']
            }

            # Если фильтры переданы, добавляем их (поддерживаются ключи "where" и "where_document")
            if filters:
                for key in ['where', 'where_document']:
                    if key in filters:
                        query_params[key] = filters[key]

            # Выполняем запрос с учетом фильтров
            results = collection.query(**query_params)

            model_used = model_name or os.getenv('CHROMA_MODEL', 'text-embedding-3-large')

            return {
                "status": "success",
                "results": {
                    "documents": results['documents'][0],
                    "metadatas": results['metadatas'][0],
                    "distances": results['distances'][0],
                    "ids": results['ids'][0],
                    "model_used": model_used
                }
            }

        except Exception as e:
            logging.error(f"Error querying collection: {str(e)}")
            raise
