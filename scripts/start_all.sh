#!/bin/bash

# Скрипт для запуска всех сервисов: Manticore, Sphinx и Web UI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Проверка Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker не запущен"
        exit 1
    fi
    
    log_info "Docker доступен"
}

# Остановка существующих контейнеров
stop_existing() {
    log_step "Остановка существующих контейнеров..."
    
    docker stop manticore-search-test 2>/dev/null || true
    docker rm manticore-search-test 2>/dev/null || true
    
    docker stop sphinx-search 2>/dev/null || true
    docker rm sphinx-search 2>/dev/null || true
    
    log_info "Существующие контейнеры остановлены"
}

# Запуск Manticore Search
start_manticore() {
    log_step "Запуск Manticore Search..."
    
    cd "$PROJECT_DIR"
    bash scripts/setup.sh
    
    # Ждем запуска
    sleep 10
    
    # Проверяем доступность
    if curl -s http://localhost:9308 > /dev/null; then
        log_info "✓ Manticore Search запущен (порт 9308)"
    else
        log_error "✗ Manticore Search недоступен"
        return 1
    fi
}

# Запуск Sphinx Search
start_sphinx() {
    log_step "Запуск Sphinx Search..."
    
    cd "$PROJECT_DIR"
    bash scripts/start_sphinx.sh
    
    # Ждем запуска
    sleep 15
    
    # Проверяем доступность
    if mysql -h 127.0.0.1 -P 9304 -e "SHOW TABLES;" 2>/dev/null | grep -q documents; then
        log_info "✓ Sphinx Search запущен (порт 9304)"
    else
        log_error "✗ Sphinx Search недоступен"
        return 1
    fi
}

# Запуск Web UI
start_web_ui() {
    log_step "Запуск Web UI..."
    
    # Останавливаем существующий процесс
    pkill -f "node server.js" 2>/dev/null || true
    sleep 2
    
    cd "$PROJECT_DIR"
    bash scripts/start_web_ui.sh &
    
    # Ждем запуска
    sleep 5
    
    # Проверяем доступность
    if curl -s http://localhost:3000/health > /dev/null; then
        log_info "✓ Web UI запущен (порт 3000)"
    else
        log_error "✗ Web UI недоступен"
        return 1
    fi
}

# Проверка всех сервисов
check_services() {
    log_step "Проверка всех сервисов..."
    
    echo ""
    echo "=== СТАТУС СЕРВИСОВ ==="
    
    # Manticore
    if curl -s http://localhost:9308 > /dev/null; then
        echo -e "Manticore Search: ${GREEN}✓ Работает${NC} (http://localhost:9308)"
    else
        echo -e "Manticore Search: ${RED}✗ Недоступен${NC}"
    fi
    
    # Sphinx
    if mysql -h 127.0.0.1 -P 9304 -e "SELECT COUNT(*) FROM documents;" 2>/dev/null > /dev/null; then
        local count=$(mysql -h 127.0.0.1 -P 9304 -e "SELECT COUNT(*) FROM documents;" 2>/dev/null | tail -1)
        echo -e "Sphinx Search: ${GREEN}✓ Работает${NC} (порт 9304, документов: $count)"
    else
        echo -e "Sphinx Search: ${RED}✗ Недоступен${NC}"
    fi
    
    # Web UI
    if curl -s http://localhost:3000/health > /dev/null; then
        echo -e "Web UI: ${GREEN}✓ Работает${NC} (http://localhost:3000)"
    else
        echo -e "Web UI: ${RED}✗ Недоступен${NC}"
    fi
    
    echo ""
    echo "=== КОНТЕЙНЕРЫ DOCKER ==="
    docker ps --filter "name=manticore-search-test" --filter "name=sphinx-search" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "=== ПРОЦЕССЫ NODE.JS ==="
    ps aux | grep "node server.js" | grep -v grep || echo "Нет активных процессов Node.js"
}

# Основная функция
main() {
    echo "🚀 Запуск всех сервисов Manticore Search Tester"
    echo ""
    
    check_docker
    stop_existing
    
    # Запускаем сервисы
    start_manticore
    start_sphinx  
    start_web_ui
    
    echo ""
    check_services
    
    echo ""
    log_info "🎉 Все сервисы запущены успешно!"
    echo ""
    echo "Доступные интерфейсы:"
    echo "  • Web UI: http://localhost:3000"
    echo "  • Manticore API: http://localhost:9308"
    echo "  • Sphinx MySQL: mysql -h 127.0.0.1 -P 9304"
    echo ""
    echo "Для остановки всех сервисов:"
    echo "  docker stop manticore-search-test sphinx-search"
    echo "  pkill -f 'node server.js'"
}

# Обработка сигналов
trap 'echo ""; log_warn "Прервано пользователем"; exit 1' INT TERM

# Запуск
main "$@"