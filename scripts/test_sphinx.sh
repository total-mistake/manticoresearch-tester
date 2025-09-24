#!/bin/bash

# Тест Sphinx через различные методы подключения

CONTAINER_NAME="sphinx-search"

echo "=== Проверка статуса контейнера ==="
docker ps --filter "name=$CONTAINER_NAME"

echo -e "\n=== Проверка процессов в контейнере ==="
docker exec "$CONTAINER_NAME" ps aux | grep -E "(searchd|indexer)"

echo -e "\n=== Проверка портов внутри контейнера ==="
docker exec "$CONTAINER_NAME" netstat -tuln | grep -E "(9304|9312)"

echo -e "\n=== Тест поиска через SphinxQL ==="
# Попробуем простой запрос
if docker exec "$CONTAINER_NAME" mysql -h 127.0.0.1 -P 9312 -e "SELECT * FROM documents WHERE MATCH('тест') LIMIT 5;" 2>/dev/null; then
    echo "✓ SphinxQL работает"
else
    echo "✗ SphinxQL не работает"
fi

echo -e "\n=== Тест поиска через MySQL протокол ==="
if docker exec "$CONTAINER_NAME" mysql -h 127.0.0.1 -P 9304 -e "SELECT * FROM documents WHERE MATCH('тест') LIMIT 5;" 2>/dev/null; then
    echo "✓ MySQL протокол работает"
else
    echo "✗ MySQL протокол не работает"
fi

echo -e "\n=== Логи searchd ==="
docker exec "$CONTAINER_NAME" tail -10 /var/log/sphinx/searchd.log 2>/dev/null || echo "Логи недоступны"