#!/bin/bash

# Скрипт для запуска Sphinx Search через Docker
set -e

# Конфигурация
SPHINX_IMAGE="sphinxsearch:2.2.7"  # Измените на ваш локальный образ если нужно
CONTAINER_NAME="sphinx-search"
SPHINX_PORT="9312"  # Изменен с 9312 на свободный порт
MYSQL_PORT="9304"   # Изменен с 9306 на свободный порт
WEB_PORT="8080"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка наличия Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен. Установите Docker и повторите попытку."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker не запущен. Запустите Docker и повторите попытку."
        exit 1
    fi
    
    log_info "Docker доступен"
}

# Проверка наличия образа
check_sphinx_image() {
    log_info "Проверка наличия образа Sphinx..."
    
    if ! docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "$SPHINX_IMAGE"; then
        log_warn "Образ $SPHINX_IMAGE не найден локально"
        log_info "Попытка загрузки образа..."
        
        if ! docker pull "$SPHINX_IMAGE"; then
            log_error "Не удалось загрузить образ $SPHINX_IMAGE"
            log_info "Убедитесь, что образ доступен или измените SPHINX_IMAGE в скрипте"
            exit 1
        fi
    fi
    
    log_info "Образ Sphinx доступен: $SPHINX_IMAGE"
}

# Создание необходимых директорий
create_directories() {
    log_info "Создание необходимых директорий..."
    
    # Создаем директории только если они не существуют
    [ ! -d "logs" ] && mkdir -p logs
    [ ! -d "output" ] && mkdir -p output
    
    # Проверяем права записи
    if [ ! -w "logs" ] || [ ! -w "output" ]; then
        log_warn "Недостаточно прав для записи в директории logs или output"
        log_info "Попробуйте выполнить: sudo chown -R \$USER:\$USER logs output"
    fi
    
    log_info "Директории готовы"
}

# Остановка существующих контейнеров
stop_existing_containers() {
    log_info "Остановка существующих контейнеров..."
    
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        docker stop "$CONTAINER_NAME" || true
        docker rm "$CONTAINER_NAME" || true
        log_info "Контейнер $CONTAINER_NAME остановлен"
    fi
}

# Запуск Sphinx через Docker
start_sphinx() {
    log_info "Запуск Sphinx Search..."
    
    # Получаем абсолютные пути
    local current_dir=$(pwd)
    
    # Запуск контейнера Sphinx
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$SPHINX_PORT:9312" \
        -p "$MYSQL_PORT:9304" \
        -v "$current_dir/configs/sphinx.conf:/etc/sphinx/sphinx.conf:ro" \
        -v "$current_dir/scripts/sphinx_data_generator.sh:/usr/local/bin/sphinx_data_generator.sh:ro" \
        -v "$current_dir/scripts/sphinx_entrypoint.sh:/entrypoint.sh:ro" \
        -v "$current_dir/data:/var/lib/sphinx/data" \
        -v "$current_dir/output:/var/lib/sphinx/output" \
        -v "$current_dir/logs:/var/log/sphinx" \
        --restart unless-stopped \
        --entrypoint /entrypoint.sh \
        "$SPHINX_IMAGE"
    
    if [ $? -eq 0 ]; then
        log_info "Sphinx Search запущен успешно"
    else
        log_error "Ошибка при запуске Sphinx Search"
        return 1
    fi
}

# Проверка статуса контейнера
check_status() {
    log_info "Проверка статуса контейнера..."
    
    sleep 5
    
    if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
        log_info "Sphinx Search контейнер запущен"
        
        # Показываем информацию о контейнере
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_error "Sphinx Search контейнер не запущен"
        log_info "Логи контейнера:"
        docker logs "$CONTAINER_NAME" 2>/dev/null || log_warn "Не удалось получить логи"
        return 1
    fi
}

# Тест подключения к Sphinx
test_connection() {
    log_info "Тестирование подключения к Sphinx..."
    
    # Ждем запуска сервиса
    sleep 10
    
    # Проверяем доступность через MySQL протокол
    if command -v mysql &> /dev/null; then
        if mysql -h 127.0.0.1 -P "$MYSQL_PORT" -e "SHOW TABLES;" 2>/dev/null; then
            log_info "✓ Подключение к Sphinx через MySQL протокол успешно"
        else
            log_warn "✗ Не удалось подключиться через MySQL протокол (порт $MYSQL_PORT)"
            log_info "Проверьте логи: docker logs $CONTAINER_NAME"
        fi
    else
        log_warn "MySQL клиент не установлен, пропускаем тест подключения"
        log_info "Установите MySQL клиент: sudo apt-get install mysql-client"
    fi
    
    # Проверяем доступность портов
    if netstat -tuln 2>/dev/null | grep -q ":$SPHINX_PORT "; then
        log_info "✓ SphinxQL порт $SPHINX_PORT доступен"
    else
        log_warn "✗ SphinxQL порт $SPHINX_PORT недоступен"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":$MYSQL_PORT "; then
        log_info "✓ MySQL протокол порт $MYSQL_PORT доступен"
    else
        log_warn "✗ MySQL протокол порт $MYSQL_PORT недоступен"
    fi
}

# Показать информацию о запущенных сервисах
show_info() {
    log_info "Информация о запущенном сервисе:"
    echo ""
    echo "Sphinx Search контейнер: $CONTAINER_NAME"
    echo "  - Образ: $SPHINX_IMAGE"
    echo "  - SphinxQL порт: $SPHINX_PORT"
    echo "  - MySQL протокол: $MYSQL_PORT"
    echo "  - Подключение: mysql -h 127.0.0.1 -P $MYSQL_PORT"
    echo ""
    echo "Управление:"
    echo "  - Остановить: docker stop $CONTAINER_NAME"
    echo "  - Удалить: docker rm $CONTAINER_NAME"
    echo "  - Логи: docker logs -f $CONTAINER_NAME"
    echo "  - Статус: docker ps --filter name=$CONTAINER_NAME"
    echo "  - Поиск: ./scripts/sphinx_search.sh -s \"запрос\""
    echo ""
    echo "Файлы конфигурации:"
    echo "  - Конфигурация: configs/sphinx.conf"
    echo "  - Данные: data/"
    echo "  - Индексы: output/"
    echo "  - Логи: logs/"
}

# Основная функция
main() {
    log_info "Запуск Sphinx Search с образом $SPHINX_IMAGE"
    
    check_docker
    check_sphinx_image
    create_directories
    stop_existing_containers
    start_sphinx
    check_status
    test_connection
    show_info
    
    log_info "Sphinx Search успешно запущен!"
}

# Обработка прерывания
trap 'log_error "Запуск прерван"; exit 1' INT TERM

# Запуск основной функции
main "$@"