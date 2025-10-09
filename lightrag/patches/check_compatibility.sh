#!/bin/bash
# Проверка совместимости патча LightRAG с новой версией образа
# Использование: ./check_compatibility.sh

set -e

echo "🔍 Checking LightRAG patch compatibility..."
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Скачать новый образ
echo "📦 Pulling latest LightRAG image..."
docker pull ghcr.io/hkuds/lightrag:latest

# Извлечь версию образа
IMAGE_VERSION=$(docker inspect ghcr.io/hkuds/lightrag:latest --format='{{.Created}}')
echo "📅 Image created: $IMAGE_VERSION"
echo ""

# Извлечь файл из нового образа
echo "📄 Extracting document_routes.py from new image..."
NEW_FILE=$(docker run --rm ghcr.io/hkuds/lightrag:latest cat /app/lightrag/api/routers/document_routes.py 2>/dev/null)

# Проверить, что файл существует
if [ -z "$NEW_FILE" ]; then
    echo -e "${RED}❌ WARNING: File /app/lightrag/api/routers/document_routes.py not found in new image!${NC}"
    echo "   Possible reasons:"
    echo "   - File was moved to another location"
    echo "   - Architecture changed significantly"
    echo "   - Manual investigation required"
    exit 1
fi

echo "✅ File found in new image"
echo ""

# Проверить, исправлен ли баг в upstream
echo "🔎 Checking if bug is fixed in upstream..."
if echo "$NEW_FILE" | grep -q "file_path: Optional\[str\]"; then
    echo -e "${GREEN}✅ GOOD NEWS: Bug is fixed in upstream!${NC}"
    echo "   file_path is now Optional[str] in upstream version"
    echo ""
    echo "🗑️  RECOMMENDATION: Remove patch from docker-compose.yml:"
    echo "   1. Edit docker-compose.yml"
    echo "   2. Remove line: - ./lightrag/patches/document_routes.py:/app/lightrag/api/routers/document_routes.py:ro"
    echo "   3. Restart container: docker compose up -d --force-recreate lightrag"
    echo "   4. Move patch to DEPRECATED: git mv lightrag/patches/document_routes.py lightrag/patches/DEPRECATED_document_routes.py"
    echo ""
    exit 0
fi

echo -e "${YELLOW}⚠️  Patch still needed - bug not fixed in upstream${NC}"
echo ""

# Проверить, что структура модели не изменилась критично
echo "🔍 Checking model structure compatibility..."

if ! echo "$NEW_FILE" | grep -q "class DocStatusResponse"; then
    echo -e "${RED}❌ CRITICAL: DocStatusResponse model not found!${NC}"
    echo "   Model structure changed significantly"
    echo "   Manual update required!"
    echo ""
    echo "📋 Action items:"
    echo "   1. Extract new file: docker run --rm ghcr.io/hkuds/lightrag:latest cat /app/lightrag/api/routers/document_routes.py > /tmp/new_version.py"
    echo "   2. Compare with patch: diff lightrag/patches/document_routes.py /tmp/new_version.py"
    echo "   3. Manually merge changes"
    exit 2
fi

echo "✅ Model structure found"

# Проверить наличие поля file_path
if ! echo "$NEW_FILE" | grep -q "file_path.*Field"; then
    echo -e "${RED}❌ WARNING: file_path field not found in DocStatusResponse!${NC}"
    echo "   Model structure may have changed"
    echo "   Manual verification recommended"
    exit 3
fi

echo "✅ file_path field found"
echo ""

# Проверить синтаксис (basic check)
echo "🔍 Checking Python syntax..."
docker run --rm -v "$(pwd)/lightrag/patches:/patches:ro" \
    ghcr.io/hkuds/lightrag:latest \
    python -m py_compile /patches/document_routes.py 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Python syntax valid"
else
    echo -e "${RED}❌ Syntax error in patch!${NC}"
    echo "   Patch may be incompatible with new Python version"
    exit 4
fi

echo ""
echo -e "${GREEN}✅ CONCLUSION: Patch is compatible with new version${NC}"
echo ""
echo "📋 Next steps:"
echo "   1. Update container: docker compose up -d --force-recreate lightrag"
echo "   2. Check logs: docker logs service_lightrag --tail 50"
echo "   3. Test endpoint: curl -X POST https://your-domain.com:7040/documents/paginated ..."
echo "   4. Monitor for errors: docker logs service_lightrag -f"
echo ""
echo "📌 Note: Keep monitoring upstream repository for permanent fix:"
echo "   https://github.com/hkuds/lightrag/issues"
