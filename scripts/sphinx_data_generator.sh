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

# Извлечение заголовка из markdown (после #)
extract_title() {
    local file_path="$1"
    grep -m 1 "^# " "$file_path" | sed 's/^# //' 2>/dev/null || echo ""
}

# Извлечение URL из markdown (после **URL:**)
extract_url() {
    local file_path="$1"
    grep "^\*\*URL:\*\*" "$file_path" | sed 's/^\*\*URL:\*\* *//' 2>/dev/null || echo ""
}

# Извлечение контента (весь текст после URL до конца документа)
extract_content() {
    local file_path="$1"
    # Берем все строки после URL до конца файла, пропуская первую пустую строку
    awk '/^\*\*URL:\*\*/{found=1; next} found {if(first_empty && NF==0) {first_empty=0; next} if(!first_empty && NF==0) first_empty=1; if(!first_empty || NF>0) print}' "$file_path" 2>/dev/null || echo ""
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
                    echo "[DEBUG] Processing file: $(basename "$file_path")" >&2
                    echo "[DEBUG] Title: $title" >&2
                    echo "[DEBUG] URL: $url" >&2
                    echo "[DEBUG] Content: ${content:0:100}..." >&2
                    echo "[DEBUG] ---" >&2
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