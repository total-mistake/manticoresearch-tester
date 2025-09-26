#!/bin/bash

# Скрипт для загрузки данных через скрапинг sitemap.xml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🔍 Starting data scraping from sitemap..."

# Проверяем наличие Go
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go first."
    exit 1
fi

# Проверяем аргументы
if [ $# -eq 0 ]; then
    echo "Usage: $0 <sitemap_url>"
    echo "Example: $0 https://example.com/sitemap.xml"
    exit 1
fi

SITEMAP_URL="$1"

echo "📥 Sitemap URL: $SITEMAP_URL"

# Инициализируем Go модуль если нужно
if [ ! -f "go.sum" ]; then
    echo "📦 Installing Go dependencies..."
    go mod tidy
fi

# Создаем резервную копию существующих данных
if [ -d "data" ] && [ "$(ls -A data)" ]; then
    BACKUP_DIR="data_backup_$(date +%Y%m%d_%H%M%S)"
    echo "💾 Creating backup: $BACKUP_DIR"
    cp -r data "$BACKUP_DIR"
fi

# Запускаем скрапер
echo "🚀 Running scraper..."
go run scraper.go "$SITEMAP_URL"

# Подсчитываем результаты
if [ -d "data" ]; then
    FILE_COUNT=$(find data -name "*.md" | wc -l)
    echo "✅ Scraping completed! Downloaded $FILE_COUNT files to data/ directory"
    
    # Показываем несколько примеров
    echo ""
    echo "📄 Sample files:"
    find data -name "*.md" | head -5 | while read file; do
        echo "  - $(basename "$file")"
    done
    
    if [ "$FILE_COUNT" -gt 5 ]; then
        echo "  ... and $((FILE_COUNT - 5)) more files"
    fi
else
    echo "❌ No data directory found after scraping"
    exit 1
fi

echo ""
echo "🎯 Next steps:"
echo "  1. Review the downloaded files in data/ directory"
echo "  2. Run ./scripts/import_data.sh to import into Manticore Search"
echo "  3. Test search with ./scripts/search_nl.sh \"your query\""