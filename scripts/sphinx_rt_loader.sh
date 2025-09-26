#!/bin/bash

# Загрузчик данных для real-time индекса Sphinx
set -e

DATA_DIR="/var/lib/sphinx/data"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="9304"

# Функция для экранирования SQL
escape_sql() {
    local input="$1"
    echo "$input" | sed "s/'/''/g"
}

# Извлечение данных из MD файлов (те же функции)
extract_title() {
    local file_path="$1"
    grep -m 1 "^# " "$file_path" | sed 's/^# //' 2>/dev/null || echo ""
}

extract_url() {
    local file_path="$1"
    grep "^\*\*URL:\*\*" "$file_path" | sed 's/^\*\*URL:\*\* *//' 2>/dev/null || echo ""
}

extract_content() {
    local file_path="$1"
    awk '/^\*\*URL:\*\*/{found=1; next} found {if(first_empty && NF==0) {first_empty=0; next} if(!first_empty && NF==0) first_empty=1; if(!first_empty || NF>0) print}' "$file_path" 2>/dev/null || echo ""
}

# Основная функция загрузки
main() {
    echo "Загрузка данных в real-time индекс..."
    
    # Очищаем индекс
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "TRUNCATE RTINDEX documents;" 2>/dev/null || true
    
    local id=1
    
    if [ -d "$DATA_DIR" ]; then
        find "$DATA_DIR" -name "*.md" -type f | sort | while read -r file_path; do
            if [ -f "$file_path" ] && [ -s "$file_path" ]; then
                local title=$(extract_title "$file_path")
                local content=$(extract_content "$file_path")
                local url=$(extract_url "$file_path")
                
                if [ -n "$title" ] && [ -n "$content" ]; then
                    
                    # Экранируем данные для SQL
                    local title_escaped=$(escape_sql "$title")
                    local content_escaped=$(escape_sql "$content")
                    local url_escaped=$(escape_sql "$url")
                    
                    # Вставляем в RT индекс
                    if ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "INSERT INTO documents (id, title, content, title_text, content_text, url) VALUES ($id, '$title_escaped', '$content_escaped', '$title_escaped', '$content_escaped', '$url_escaped');" 2>&1; then
                        echo "[ERROR] Failed to insert document $id: $(basename "$file_path")" >&2
                        echo "[ERROR] Title length: ${#title}, Content length: ${#content}" >&2
                    fi
                    
                    id=$((id + 1))
                fi
            fi
        done
    fi
    
    echo "Загрузка завершена. Загружено документов: $((id - 1))"
    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "SELECT * FROM documents LIMIT 1;"
}

main