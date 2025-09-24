#!/bin/bash

# Скрипт для поиска через Sphinx Search
set -e

# Конфигурация
SPHINX_PORT="9304"
LIMIT=10
VERBOSE=false
JSON_OUTPUT=false

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции логирования
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Показать справку
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ] ЗАПРОС

Поиск по документам через Sphinx Search

ОПЦИИ:
    -s, --search ЗАПРОС    Поисковый запрос (обязательно)
    -l, --limit ЧИСЛО      Лимит результатов (по умолчанию: $LIMIT)
    -j, --json             Вывод в формате JSON
    -v, --verbose          Подробный вывод
    -h, --help             Показать эту справку

ПРИМЕРЫ:
    $0 -s "тест"
    $0 --search "как создать сайт" --limit 5
    $0 -s "FTP доступ" --json --verbose

EOF
}

# Парсинг аргументов
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--search)
                SEARCH_QUERY="$2"
                shift 2
                ;;
            -l|--limit)
                LIMIT="$2"
                shift 2
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$SEARCH_QUERY" ]; then
                    SEARCH_QUERY="$1"
                else
                    log_error "Неизвестный аргумент: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$SEARCH_QUERY" ]; then
        log_error "Не указан поисковый запрос"
        show_help
        exit 1
    fi
}

# Проверка подключения к Sphinx
check_sphinx() {
    if ! mysql -h 127.0.0.1 -P "$SPHINX_PORT" -e "SHOW TABLES;" >/dev/null 2>&1; then
        log_error "Не удается подключиться к Sphinx Search"
        log_info "Убедитесь, что контейнер запущен: docker ps --filter name=sphinx-search"
        log_info "Или запустите: ./scripts/start_sphinx.sh"
        exit 1
    fi
}

# Экранирование запроса для SQL
escape_query() {
    local query="$1"
    # Экранируем одинарные кавычки
    echo "$query" | sed "s/'/''/g"
}

# Выполнение поиска
perform_search() {
    local escaped_query=$(escape_query "$SEARCH_QUERY")
    local start_time=$(date +%s.%N)
    
    if [ "$VERBOSE" = true ]; then
        log_info "Выполнение поиска: '$SEARCH_QUERY'"
        log_info "Лимит результатов: $LIMIT"
    fi
    
    # SQL запрос для поиска
    local sql="SELECT id, url, created_at, title_text, content_text, WEIGHT() as score FROM documents WHERE MATCH('$escaped_query') ORDER BY score DESC LIMIT $LIMIT;"
    
    if [ "$VERBOSE" = true ]; then
        log_info "SQL запрос: $sql"
    fi
    
    # Выполняем поиск
    local results=$(mysql -h 127.0.0.1 -P "$SPHINX_PORT" -e "$sql" 2>/dev/null)
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local duration_ms=$(echo "$duration * 1000" | bc -l | cut -d. -f1)
    
    if [ $exit_code -ne 0 ]; then
        log_error "Ошибка выполнения поиска"
        return 1
    fi
    
    # Подсчет результатов
    local result_count=$(echo "$results" | tail -n +2 | wc -l)
    
    if [ "$JSON_OUTPUT" = true ]; then
        format_json_output "$results" "$result_count" "$duration_ms"
    else
        format_text_output "$results" "$result_count" "$duration_ms"
    fi
}

# Форматирование вывода в JSON
format_json_output() {
    local results="$1"
    local count="$2"
    local duration="$3"
    
    local max_score=0
    if [ $count -gt 0 ]; then
        max_score=$(echo "$results" | tail -n +2 | head -1 | awk -F'\t' '{print $NF}' | bc -l 2>/dev/null || echo "0")
    fi
    
    echo "{"
    echo "  \"total\": $count,"
    echo "  \"took\": $duration,"
    echo "  \"max_score\": $max_score,"
    echo "  \"hits\": ["
    
    local first=true
    echo "$results" | tail -n +2 | while IFS=$'\t' read -r id url created_at title_text content_text score; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        # Очищаем данные от лишних символов
        local clean_title=$(echo "$title_text" | sed 's/"/\\"/g')
        local clean_content=$(echo "$content_text" | sed 's/"/\\"/g')
        
        # Если заголовок пустой, создаем из URL
        if [ -z "$clean_title" ]; then
            clean_title=$(basename "$url" | sed 's/_/ /g' | sed 's/\..*$//')
        fi
        
        echo "    {"
        echo "      \"_id\": \"$id\","
        echo "      \"_score\": $(echo "scale=3; $score / 1000" | bc -l),"
        echo "      \"_source\": {"
        echo "        \"title\": \"$clean_title\","
        echo "        \"url\": \"$url\","
        echo "        \"content\": \"$clean_content\""
        echo "      }"
        echo -n "    }"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Форматирование текстового вывода
format_text_output() {
    local results="$1"
    local count="$2"
    local duration="$3"
    
    echo ""
    echo "🔍 Результаты поиска для: \"$SEARCH_QUERY\""
    echo "📊 Найдено результатов: $count"
    echo "⏱️  Время выполнения: ${duration}ms"
    echo ""
    
    if [ $count -eq 0 ]; then
        echo "❌ Ничего не найдено"
        echo ""
        echo "💡 Попробуйте:"
        echo "   - Использовать другие ключевые слова"
        echo "   - Упростить запрос"
        echo "   - Проверить правописание"
        return
    fi
    
    local counter=1
    echo "$results" | tail -n +2 | while IFS=$'\t' read -r id url created_at title_text content_text score; do
        local title="$title_text"
        if [ -z "$title" ]; then
            title=$(basename "$url" | sed 's/_/ /g' | sed 's/\..*$//')
        fi
        
        echo "[$counter] 📄 $title (ID: $id, Score: $score)"
        echo "    🔗 $url"
        echo "    📅 $(date -d @$created_at '+%Y-%m-%d %H:%M:%S')"
        if [ -n "$content_text" ]; then
            echo "    📝 $content_text"
        fi
        echo ""
        counter=$((counter + 1))
    done
}

# Основная функция
main() {
    parse_args "$@"
    
    if [ "$VERBOSE" = true ]; then
        log_info "Sphinx Search - поиск по документам"
    fi
    
    check_sphinx
    perform_search
}

# Запуск
main "$@"