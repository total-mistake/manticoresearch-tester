# Dual Search Engine Testing Framework

Комплексный фреймворк для сравнительного тестирования поисковых движков Manticore Search и Sphinx Search с поддержкой естественных запросов на русском языке.

## Особенности проекта

- 🔄 **Два поисковых движка** - Manticore Search (AI + Auto Embeddings) и Sphinx Search (классический)
- 🧠 **Auto Embeddings** - Семантический поиск в Manticore Search
- 🔍 **Сравнительный анализ** - Тестирование качества поиска разных движков
- 🌐 **Веб-интерфейс** - Удобное переключение между движками
- 🇷🇺 **Русский язык** - Оптимизация для русскоязычного контента
- 📊 **Автотесты** - 27 естественных запросов для оценки качества
- 📈 **Детальная аналитика** - JSON отчеты и метрики качества поиска

## Структура проекта

```
.
├── scripts/              # Скрипты автоматизации
│   ├── start_all.sh     # Запуск всех сервисов (НОВОЕ!)
│   ├── setup.sh         # Настройка Manticore Search
│   ├── start_sphinx.sh  # Запуск Sphinx Search
│   ├── start_web_ui.sh  # Запуск веб-интерфейса
│   ├── search_nl.sh     # Поиск через Manticore
│   ├── sphinx_search.sh # Поиск через Sphinx
│   ├── import_data.sh   # Импорт данных в Manticore
│   ├── run_tests.sh     # Автотесты (27 запросов)
│   └── health_check.sh  # Проверка состояния системы
├── configs/              # Конфигурационные файлы
│   ├── manticore.conf   # Конфигурация Manticore Search
│   └── sphinx.conf      # Конфигурация Sphinx Search
├── web/                  # Веб-интерфейс (НОВОЕ!)
│   ├── index.html       # Основная страница
│   ├── server.js        # Node.js сервер
│   └── package.json     # Зависимости Node.js
├── data/                # Исходные данные (500+ Markdown файлов)
├── output/              # Индексы и результаты тестов
├── docs/               # Документация
└── logs/               # Логи выполнения
```

## Быстрый старт

### 🚀 Одной командой (Рекомендуемо!)

```bash
# Запуск всех сервисов: Manticore + Sphinx + Web UI
./scripts/start_all.sh

# Откройте браузер: http://localhost:3000
```

### 🔧 Пошаговый запуск

```bash
# 1. Запуск Manticore Search
./scripts/setup.sh
./scripts/import_data.sh

# 2. Запуск Sphinx Search
./scripts/start_sphinx.sh

# 3. Запуск веб-интерфейса
./scripts/start_web_ui.sh

# 4. Проверка
./scripts/health_check.sh
```

### 📊 Автотесты

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

- **[QUICKSTART.md](QUICKSTART.md)**
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Архитектура и компоненты системы
- **[README_SPHINX.md](README_SPHINX.md)** - Документация по Sphinx Search
- **[docs/web_ui_guide.md](docs/web_ui_guide.md)** - Подробное руководство по веб-интерфейсу
- **[docs/checklist.md](docs/checklist.md)** - Контрольный список развертывания  
- **[docs/examples.md](docs/examples.md)** - Примеры использования и команд

## 🔗 Внешние ресурсы

- [Документация Manticore Search](https://manual.manticoresearch.com/)
- [Auto Embeddings Guide](https://manual.manticoresearch.com/Searching/Auto_Embeddings)
- [Русская морфология](https://manual.manticoresearch.com/Creating_an_index/NLP_and_tokenization/Morphology)
- [Docker Hub - Manticore Search](https://hub.docker.com/r/manticoresearch/manticore)

## 🌐 Веб-интерфейс с выбором движка

Проект включает современный веб-интерфейс для сравнительного тестирования:

```bash
# Запуск веб-интерфейса
./scripts/start_web_ui.sh

# Откройте браузер: http://localhost:3000
```

**Ключевые возможности:**
- 🔄 **Выбор поискового движка** - Manticore Search или Sphinx Search
- 🔍 Поисковая строка с автодополнением примеров
- 📊 Отображение ранжированных результатов с score (0-100)
- ⚡ Метрики производительности (время ответа, max_score)
- 📱 Адаптивный дизайн для мобильных устройств
- 🎛️ Настройка лимита результатов и подробного режима
- 📝 Полные заголовки и описания документов
- 🔍 Просмотр и анализ логов с помощью `./scripts/view_logs.sh`

## 🎯 Готовые команды

```bash
# 🚀 Полное развертывание всех сервисов
./scripts/start_all.sh

# 🌐 Запуск веб-интерфейса (рекомендуемо)
./scripts/start_web_ui.sh

# 🔍 Быстрый тест через Manticore
./scripts/search_nl.sh "Ваш естественный запрос"

# 🔍 Быстрый тест через Sphinx
./scripts/sphinx_search.sh -s "Ваш запрос"

# 📊 Полное тестирование (27 запросов)
./scripts/run_tests.sh

# 🔧 Диагностика системы
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

## 📄 О проекте

Проект создан для сравнительного анализа современных и классических подходов к поиску:

- **Manticore Search 13.11.0** - семантический поиск с AI и Auto Embeddings
- **Sphinx Search 2.2.7** - классический полнотекстовый поиск

Используйте как основу для выбора оптимального поискового решения для ваших задач.

**Разработано в 2025 году для сравнительного тестирования поисковых движков на русскоязычном контенте.**