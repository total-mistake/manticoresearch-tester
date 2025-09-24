#!/bin/bash

# Генератор XML данных для Sphinx из markdown файлов
# Этот скрипт читает markdown файлы и генерирует XML в формате xmlpipe2

set -e

DATA_DIR="/var/lib/sphinx/data"

# Функция для экранирования XML
escape_xml() {
    local input="$1"
    # Только экранируем XML символы, не удаляем русские буквы
    echo "$input" | \
        sed 's/&/\&amp;/g' | \
        sed 's/</\&lt;/g' | \
        sed 's/>/\&gt;/g' | \
        sed 's/"/\&quot;/g' | \
        sed "s/'/\&apos;/g" | \
        tr '\t' ' ' | \
        tr -s ' '
}

# Извлечение заголовка из markdown
extract_title() {
    local file_path="$1"
    local title=""
    
    title=$(grep -m 1 "^#" "$file_path" | sed 's/^#* *//' | sed 's/\s*$//' 2>/dev/null || echo "")
    
    if [ -z "$title" ]; then
        title=$(basename "$file_path" .md | tr '_' ' ')
    fi
    
    echo "$title"
}

# Извлечение URL из markdown
extract_url() {
    local file_path="$1"
    local url=""
    
    url=$(grep -i "^\*\*URL:\*\*" "$file_path" | sed 's/^\*\*URL:\*\*\s*//' | sed 's/^\s*//' | sed 's/\s*$//' | head -1 2>/dev/null || echo "")
    
    if [ -z "$url" ]; then
        url=$(grep -oE "https?://[^\s]+" "$file_path" | head -1 2>/dev/null || echo "")
    fi
    
    if [ -z "$url" ]; then
        local filename=$(basename "$file_path" .md)
        url="https://nethouse.ru/about/instructions/$filename"
    fi
    
    echo "$url"
}

# Извлечение содержимого из markdown
extract_content() {
    local file_path="$1"
    local content=""
    
    content=$(tail -n +2 "$file_path" | \
        grep -v "^\*\*URL:\*\*" | \
        sed '/^$/d' | \
        sed 's/\r$//' | \
        tr '\n' ' ' | \
        sed 's/  */ /g' | \
        sed 's/^ *//' | \
        sed 's/ *$//' 2>/dev/null || echo "")
    
    echo "$content"
}

# Генерация XML заголовка
generate_xml_header() {
    cat << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<sphinx:docset>
<sphinx:schema>
<sphinx:field name="title"/>
<sphinx:field name="content"/>
<sphinx:attr name="title_text" type="string"/>
<sphinx:attr name="content_text" type="string"/>
<sphinx:attr name="url" type="string"/>
<sphinx:attr name="created_at" type="timestamp"/>
</sphinx:schema>
EOF
}

# Генерация XML документа
generate_xml_document() {
    local id="$1"
    local title="$2"
    local content="$3"
    local url="$4"
    local timestamp=$(date +%s)
    
    # Экранирование XML
    local title_escaped=$(escape_xml "$title")
    local content_escaped=$(escape_xml "$content")
    local url_escaped=$(escape_xml "$url")
    
    
    cat << EOF
<sphinx:document id="$id">
<title>$title_escaped</title>
<content>$content_escaped</content>
<title_text>$title_escaped</title_text>
<content_text>$content_escaped</content_text>
<url>$url_escaped</url>
<created_at>$timestamp</created_at>
</sphinx:document>
EOF
}

# Генерация XML футера
generate_xml_footer() {
    echo "</sphinx:docset>"
}

# Основная функция
main() {
    generate_xml_header
    
    local id=1
    
    if [ -d "$DATA_DIR" ]; then
        find "$DATA_DIR" -name "*.md" -type f | sort | while read -r file_path; do
            if [ -f "$file_path" ] && [ -s "$file_path" ]; then
                local title=$(extract_title "$file_path")
                local content=$(extract_content "$file_path")
                local url=$(extract_url "$file_path")
                
                if [ -n "$title" ] && [ -n "$content" ]; then
                    generate_xml_document "$id" "$title" "$content" "$url"
                    id=$((id + 1))
                fi
            fi
        done
    fi
    
    generate_xml_footer
}

# Запуск
main