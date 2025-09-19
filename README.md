# Manticore Search AI Testing Framework

Комплексный фреймворк для тестирования возможностей Auto Embeddings и AI Search в Manticore Search 13.11.0 с поддержкой естественных запросов на русском языке.

## Особенности проекта

- 🧠 **Auto Embeddings** - Автоматическая генерация векторных представлений
- 🔍 **Семантический поиск** - Поиск по смыслу, а не только по ключевым словам
- 🇷🇺 **Русский язык** - Оптимизация для русскоязычного контента
- 📊 **Автотесты** - 27 естественных запросов для оценки качества
- 📈 **Детальная аналитика** - JSON отчеты и метрики качества поиска

## Структура проекта

```
.
├── scripts/              # Скрипты автоматизации
│   ├── setup.sh         # Настройка Docker-окружения
│   ├── import_data.sh   # Импорт данных в индекс
│   ├── run_tests.sh     # Запуск тестовых запросов
│   ├── search_nl.sh     # Поиск по естественному запросу
│   ├── analyze_results.sh # Анализ результатов тестирования
│   └── health_check.sh  # Проверка состояния системы
├── configs/              # Конфигурационные файлы
│   ├── manticore.conf   # Конфигурация Manticore Search
│   └── connection.conf  # Настройки подключения (автоген.)
├── data/                # Исходные данные (Markdown файлы)
├── output/              # Результаты тестирования
│   ├── *.json          # Детальные отчеты в JSON
│   ├── *.txt           # Сводные отчеты
│   └── documents/      # Индексные файлы Manticore
├── docs/               # Документация
└── logs/               # Логи выполнения
```

## Быстрый старт

### 1. Подготовка исходных данных

Поместите ваши файлы в папку `data/`. Поддерживаемые форматы:
- **Markdown файлы** (`.md`) - основной формат для тестирования
- Каждый файл должен содержать заголовок и контент на русском языке
- Имена файлов должны отражать их содержание для корректного тестирования

**Пример структуры файла:**
```markdown
# Заголовок статьи

Содержание статьи на русском языке с подробным описанием темы...
```

### 2. Развертывание системы

```bash
# 1. Настройка Manticore Search с Docker
./scripts/setup.sh

# 2. Импорт данных в поисковый индекс
./scripts/import_data.sh

# 3. Проверка работоспособности
./scripts/health_check.sh
```

### 3. Запуск тестирования

```bash
# Полное тестирование с 27 запросами
./scripts/run_tests.sh

# Просмотр результатов
cat output/test_summary_*.txt
```

## Детальное использование

### Импорт собственных данных

1. **Подготовьте файлы**: Поместите `.md` файлы в папку `data/`
2. **Запустите импорт**: `./scripts/import_data.sh`
3. **Проверьте результат**: Скрипт покажет количество обработанных файлов

### Выполнение кастомных запросов

```bash
# Поиск с форматированным выводом
./scripts/search_nl.sh "Ваш естественный запрос на русском"

# Поиск с JSON-выводом
./scripts/search_nl.sh --json "Ваш запрос"

# Поиск с ограничением результатов
./scripts/search_nl.sh --limit 5 "Ваш запрос"

# Подробный режим с отладкой
./scripts/search_nl.sh --verbose "Ваш запрос"
```

### Примеры естественных запросов

```bash
# Технические вопросы
./scripts/search_nl.sh "Есть ли доступ по FTP?"

# Вопросы о функциональности
./scripts/search_nl.sh "Поддерживается ли мобильная версия?"

# Вопросы о безопасности
./scripts/search_nl.sh "Как защищены личные данные?"

# Альтернативные формулировки
./scripts/search_nl.sh "Можно ли получить пробную версию?"
```

### Анализ результатов

```bash
# Анализ последних результатов тестирования
./scripts/analyze_results.sh

# Просмотр детального JSON-отчета
jq '.' output/test_report_*.json | head -50
```

## Системные требования

- **Docker** 20.10+ установлен и запущен
- **curl** для HTTP-запросов
- **jq** для обработки JSON (рекомендуется)
- **bc** для математических вычислений
- Свободные порты: **9306** (MySQL API) и **9308** (HTTP API)
- Интернет-соединение для загрузки Docker-образа

## Конфигурация

### Manticore Search (configs/manticore.conf)

Оптимизированная конфигурация для русского языка:
- `charset_type = utf-8` - поддержка UTF-8
- `morphology = stem_ru` - русская морфология  
- `soundex = 1` - звуковое сходство слов
- `expansion_limit = 32` - расширение поиска

### Auto Embeddings

- **Размерность векторов**: 384
- **Индексирование**: HNSW (Hierarchical Navigable Small World)
- **Метрика сходства**: Косинусное расстояние
- **Автоматическая генерация**: Для всех текстовых полей

## Интерпретация результатов

### Метрики качества поиска

- **Excellent (90-100)**: Высочайшее качество, точные результаты
- **Good (70-89)**: Хорошее качество, релевантные результаты  
- **Fair (50-69)**: Удовлетворительно, частично релевантные
- **Poor (0-49)**: Низкое качество, нерелевантные результаты

### Показатели производительности

- **Response Time**: Общее время выполнения запроса
- **Search Time**: Время поиска в индексе
- **Total Results**: Количество найденных документов
- **Top Score**: Максимальный рейтинг релевантности

## Устранение неполадок

### Проблемы с Docker

```bash
# Проверка статуса Docker
docker info

# Остановка существующих контейнеров
docker stop $(docker ps -q --filter "name=manticore")

# Очистка и перезапуск
docker system prune -f
./scripts/setup.sh
```

### Проблемы с портами

```bash
# Проверка занятых портов
lsof -i :9308
lsof -i :9306

# Завершение процессов, занимающих порты
sudo kill -9 $(lsof -ti :9308)
```

### Проблемы с поиском

```bash
# Проверка состояния индекса
./scripts/health_check.sh

# Повторный импорт данных
./scripts/import_data.sh

# Диагностика конкретного запроса
./scripts/search_nl.sh --verbose --json "ваш запрос"
```

## Расширение функциональности

### Добавление новых тестовых запросов

Отредактируйте `scripts/run_tests.sh`:
```bash
# Добавьте в массив TEST_QUERIES
"Ваш новый естественный запрос"

# Добавьте ожидаемый результат в get_expected_results()
"Ваш новый естественный запрос") echo "1" ;;
```

### Настройка собственных метрик

Измените пороги качества в `scripts/run_tests.sh`:
```bash
# Отличные результаты (90+ баллов)
if [ "$total_results" -ge "$expected_count" ] && [ "$(echo "$top_score > 0.5" | bc -l)" = "1" ]; then
    result_quality="excellent"
```

## 📚 Дополнительная документация

- **[QUICKSTART.md](QUICKSTART.md)** - Запуск за 3 минуты
- **[docs/checklist.md](docs/checklist.md)** - Контрольный список развертывания  
- **[docs/examples.md](docs/examples.md)** - Примеры использования и команд
- **[docs/improvements_summary.md](docs/improvements_summary.md)** - Отчет об улучшениях

## 🔗 Внешние ресурсы

- [Документация Manticore Search](https://manual.manticoresearch.com/)
- [Auto Embeddings Guide](https://manual.manticoresearch.com/Searching/Auto_Embeddings)
- [Русская морфология](https://manual.manticoresearch.com/Creating_an_index/NLP_and_tokenization/Morphology)
- [Docker Hub - Manticore Search](https://hub.docker.com/r/manticoresearch/manticore)

## 🎯 Готовые команды

```bash
# Полное развертывание и тестирование
./scripts/setup.sh && ./scripts/import_data.sh && ./scripts/run_tests.sh

# Быстрый тест одного запроса
./scripts/search_nl.sh "Ваш естественный запрос"

# Диагностика системы
./scripts/health_check.sh
```

## 📊 Пример успешного результата

```
OVERALL PERFORMANCE:
  - Successful Queries: 27/27 (100.0%)
  - Average Response Time: 90 ms
  - Average Results per Query: 24
  - Average Relevance Score: 90/100

SEARCH QUALITY ANALYSIS:
  - Excellent Results: 27
  - Good Results: 0
  - Poor Results: 0
```

## 🛠️ Техническая поддержка

**Быстрая диагностика:**
```bash
# Проверка статуса
docker ps --filter "name=manticore"

# Логи системы
docker logs manticore-search-test --tail 20

# Перезапуск при проблемах
docker restart manticore-search-test
```

## 📄 Лицензия и авторство

Проект создан для демонстрации возможностей **Manticore Search 13.11.0** с Auto Embeddings.
Используйте как основу для ваших поисковых решений с поддержкой AI и семантического поиска.

**Разработано в 2025 году для тестирования естественных запросов на русском языке.**