#!/bin/bash

# Entrypoint для Sphinx контейнера
set -e

echo "Запуск Sphinx Search..."

# Создаем необходимые директории
mkdir -p /var/lib/sphinx/output
mkdir -p /var/log/sphinx
mkdir -p /var/run/sphinx

# Устанавливаем права
chown -R sphinx:sphinx /var/lib/sphinx
chown -R sphinx:sphinx /var/log/sphinx

# Индексируем данные
echo "Создание индекса..."
indexer --config /etc/sphinx/sphinx.conf --all

# Запускаем searchd
echo "Запуск searchd..."
exec searchd --config /etc/sphinx/sphinx.conf --nodetach