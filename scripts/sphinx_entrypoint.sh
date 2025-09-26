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

# Удаляем старые индексы для пересоздания схемы
rm -rf /var/lib/sphinx/output/*

# Запускаем searchd в фоне для загрузки данных
echo "Запуск searchd в фоне..."
searchd --config /etc/sphinx/sphinx.conf

# Ждем запуска сервиса
sleep 10

# Загружаем данные в real-time индекс
echo "Загрузка данных в RT индекс..."
/usr/local/bin/sphinx_rt_loader.sh

# Останавливаем фоновый процесс и запускаем в foreground
echo "Перезапуск в foreground режиме..."
searchd --config /etc/sphinx/sphinx.conf --stop
sleep 2
exec searchd --config /etc/sphinx/sphinx.conf --nodetach